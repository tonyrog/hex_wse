%%%---- BEGIN COPYRIGHT -------------------------------------------------------
%%%
%%% Copyright (C) 2007 - 2014, Rogvall Invest AB, <tony@rogvall.se>
%%%
%%% This software is licensed as described in the file COPYRIGHT, which
%%% you should have received as part of this distribution. The terms
%%% are also available at http://www.rogvall.se/docs/copyright.txt.
%%%
%%% You may opt to use, copy, modify, merge, publish, distribute and/or sell
%%% copies of the Software, and permit persons to whom the Software is
%%% furnished to do so, under the terms of the COPYRIGHT file.
%%%
%%% This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
%%% KIND, either express or implied.
%%%
%%%---- END COPYRIGHT ---------------------------------------------------------
%%%-------------------------------------------------------------------
%%% @author Tony Rogvall <tony@rogvall.se>
%%% @doc
%%%   Hex plugin server
%%% @end
%%% Created : 20 Mar 2014 by Tony Rogvall <tony@rogvall.se>
%%%-------------------------------------------------------------------
-module(hex_wse_server).

-behaviour(gen_server).

%% API
-export([start_link/0, stop/0]).
-export([add_event/3, mod_event/2, del_event/1]).
-export([init_event/2, output_event/2]).

-export([new_session/2]).


%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-define(DICT_T, term()).  %% dict:dict()

-record(widget,
	{
	  id,        %% named widgets
	  type,      %% button,rectangle,slider ...
	  window = screen,   %% id of window (if type != window)
	  state  = normal,   %% or active,selected ..
	  static = false,    %% object may not be deleted
	  x = 0   :: integer(),
	  y = 0   :: integer(),
	  width  = 32 :: non_neg_integer(),
	  height = 32 :: non_neg_integer(),
	  text = "" :: string(),
	  image   :: string(),
	  color = 16#ff000000,
	  fill   = none :: epx:epx_fill_style(),
	  events = []   :: epx:epx_window_event_flags(),
	  halign  = center :: top|bottom|center,
	  valign  = center :: left|right|center,
	  min     :: number(),          %% type=value|slider
	  max     :: number(),          %% type=value|slider
	  format = "~w" :: string(),    %% io:format format
	  value =0 :: number(),         %% type=value|slider
	  animate,                      %% animation state.
	  font    :: string()           %% type=text|button|value
	}).

-record(sub,
	{
	  ref :: reference(),
	  mon :: reference(),
	  id  :: term(),
	  callback :: atom() | function(),
	  signal :: term()
	}).

-record(session,
	{
	  ws  :: pid(),        %% web socket session
	  mon :: reference(),  %% monitor of the above
	  where  :: term(),    %% id where to put the content
	  canvas :: term(),    %% canvas DOM object id
	  iref   :: term()     %% event reference
	}).
	  
-record(state, {
	  joined :: boolean(),  %% joined hex server
	  port :: integer(),    %% wse port nuber
	  wse_pid  :: pid(),  %% wse server pid
	  wse_mon  :: reference(),  %% wse server monitor

	  redraw_timer = undefined,
	  active = [] :: [term()],   %% active widgets pressed
	  subs = [] :: [#sub{}],
	  sessions = [] :: [#session{}],
	  default_font = "12px Arial",  %% default

	  widgets :: ?DICT_T   %% term => #widget{}
	 }).


add_event(Flags, Signal, Cb) ->
    gen_server:call(?MODULE, {add_event, self(), Flags, Signal, Cb}).

del_event(Ref) ->
    gen_server:call(?MODULE, {del_event, Ref}).

output_event(Flags, Env) ->
    gen_server:call(?MODULE, {output_event, Flags, Env}).

init_event(Dir, Flags) ->
    gen_server:call(?MODULE, {init_event, Dir, Flags}).

mod_event(Dir, Flags) ->
    gen_server:call(?MODULE, {mod_event, Dir, Flags}).

new_session(Ws, Where) ->
    lager:debug("calling new session: ws=~p, where=~p\n", [Ws, Where]),
    gen_server:call(?MODULE, {new_session, Ws, Where}).

stop() ->
    gen_server:call(?MODULE, stop).

start_link() ->
    hex:start_all(lager),
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init(Args) ->
    Port = proplists:get_value(port, Args, 1234),
    Wse  = spawn_link(fun() -> wse_server:init([{port,Port}]) end),
    Joined = hex:auto_join(hex_wse),
    {ok, #state{joined = Joined,
		wse_pid = Wse,
		wse_mon = undefined,
		port = Port,
		widgets = dict:new()
	       }}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------

handle_call({add_event,Pid,Flags,Signal,Cb}, _From, State) ->
    case lists:keyfind(id, 1, Flags) of
	false ->
	    {reply,{error,missing_id},State};
	{id,ID} ->
	    Ref = erlang:monitor(process, Pid),
	    Sub = #sub{id=ID,ref=Ref,signal=Signal,callback=Cb},
	    Subs = [Sub|State#state.subs],
	    {reply, {ok,Ref}, State#state { subs = Subs}}
    end;
handle_call({del_event,Ref}, _From, State) ->
    case lists:keytake(Ref, #sub.ref, State#state.subs) of
	false ->
	    {reply, {error, not_found}, State};
	{value, Sub, Subs} ->
	    erlang:demonitor(Sub#sub.ref, [flush]),
	    {reply, ok, State#state { subs=Subs} }
    end;
handle_call({output_event,Flags,Env}, _From, State) ->    
    case lists:keyfind(id, 1, Flags) of
	false ->
	    {reply,{error,missing_id},State};
	{id,ID} ->
	    case dict:find(ID, State#state.widgets) of
		error ->
		    {reply,{error,enoent},State};
		{ok,W} ->
		    try widget_set(Env, W) of
			W1 ->
			    Ws1 = dict:store(ID,W1,State#state.widgets),
			    self() ! refresh,
			    {reply, ok, State#state{widgets=Ws1}}
		    catch
			error:Reason ->
			    {reply, {error,Reason}, State}
		    end
	    end
    end;
handle_call({init_event,_Dir,Flags}, _From, State) ->
    case lists:keyfind(id, 1, Flags) of
	false ->
	    {reply,{error,missing_id},State};
	{_,ID} ->
	    case dict:find(ID,State#state.widgets) of
		error ->
		    W0 = #widget{font=State#state.default_font},
		    try widget_set(Flags,W0) of
			W ->
			    Ws1 = dict:store(ID,W,State#state.widgets),
			    self() ! refresh,
			    {reply, ok, State#state{widgets=Ws1}}
		    catch
			error:Reason ->
			    io:format("widget ~p not created ~p\n",
				      [ID, Reason]),
			    {reply, {error,Reason}, State}
		    end;
		{ok,W} ->
		    try widget_set(Flags,W) of
			W1 ->
			    Ws1 = dict:store(ID,W1,State#state.widgets),
			    self() ! refresh,
			    {reply, ok, State#state{widgets=Ws1}}
		    catch
			error:Reason ->
			    io:format("widget ~p not updated ~p\n",
				      [ID, Reason]),
			    {reply, {error,Reason}, State}
		    end
	    end
    end;
handle_call({mod_event,_Dir,Flags}, _From, State) ->
    case lookup_widget(Flags, State) of
	E={error,_} ->
	    {reply,E, State};
	{ok,W} ->
	    try widget_set(Flags, W) of
		W1 ->
		    Ws1 = dict:store(W#widget.id,W1,State#state.widgets),
		    self() ! refresh,
		    {reply, ok, State#state{widgets=Ws1}}
	    catch
		error:Reason ->
		    {reply, {error,Reason}, State}
	    end
    end;
handle_call({new_session, Ws, Where}, _From, State) ->
    lager:debug("new_session Ws=~p, Where=~p\n", [Ws,Where]),
    %% FIXME: pick up width and height!!!
    Canvas2 = wse:new(Ws, "CanvasClass", [Where,true]),
    {ok,IRef} = wse:create_event(Ws),
    %% create a function 
    IFunc = wse:newf(Ws, "event",
		     "{ var c = document.getElementById('"++Where++"'); " ++
		     "  var r = c.getBoundingClientRect(); " ++
		     " Wse.notify("++integer_to_list(IRef) ++
			 ",Ei.tuple(Ei.atom(event.type),event.button,Ei.tuple(event.clientX - r.left,event.clientY-r.top,0))); }"),
    wse:call(Ws, wse:id(Where), addEventListener, [mousedown,IFunc,false]),
    wse:call(Ws, wse:id(Where), addEventListener, [mouseup,IFunc,false]),

    Mon = erlang:monitor(process, Ws),
    Sess = #session {ws=Ws,mon=Mon,where=Where,canvas=Canvas2,iref=IRef},
    Sessions = [Sess | State#state.sessions],
    State1 = State#state { sessions = Sessions },
    redraw_session(Sess, State1),
    {reply, ok, State1};
handle_call(stop, _From, State) ->
    {reply, normal, ok, State};
handle_call(_Request, _From, State) ->
    lager:debug("unknown call ~p", [_Request]),
    {reply, {error,bad_call}, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------

handle_info({timeout,_Ref,{animate,ID,Anim}}, State) ->
    case dict:find(ID, State#state.widgets) of
	error -> {noreply, State};
	{ok,W} ->
	    W1 = widget_animate_run(W, Anim),
	    Ws = dict:store(ID,W1,State#state.widgets),
	    State1 = State#state { widgets = Ws },
	    State2 = redraw_schedule(State1),
	    {noreply,State2}
    end;
handle_info(refresh, State) ->
    {noreply, redraw_schedule(State)};
handle_info({timeout,TRef,redraw}, State) 
  when TRef =:= State#state.redraw_timer ->
    lager:debug("redraw"),
    State1 = redraw_state(State#state { redraw_timer=undefined}),
    {noreply, State1};

handle_info({'DOWN',Ref,process,_Pid,_Reason}, State) when
      Ref =:= State#state.wse_mon ->
    %% restart wse server ?
    lager:debug("wse_server down ~p", [_Reason]),
    {noreply, State#state { wse_pid=undefined, 
			    wse_mon=undefined }};

handle_info({'DOWN',Ref,process,_Pid,_Reason}, State) ->
    case lists:keytake(Ref, #sub.ref, State#state.subs) of
	false ->
	    case lists:keytake(Ref, #session.mon, State#state.sessions) of
		false ->
		    {noreply, State};
		{value, _Sess, Sessions } ->
		    lager:debug("session ~p down", [_Sess]),
		    {noreply, State#state { sessions=Sessions} }
	    end;
	{value, _Sub, Subs} ->
	    lager:debug("subscrption ~p down", [_Sub]),
	    {noreply, State#state { subs=Subs} }
    end;
handle_info(_Notify={notify,IRef,_EventData,RemoteData}, State) ->
    lager:debug("notify ~p", [_Notify]),
    case lists:keyfind(IRef, #session.iref, State#state.sessions) of
	false ->
	    {noreply, State};
	Sess ->
	    handle_event(RemoteData, Sess, State)
    end;
handle_info(_Info, State) ->
    lager:debug("info = %p", [_Info]),
    {noreply, State}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

handle_event({key_press,_Sym,_Mod,_Code},_Sess,State) ->
    {noreply, State};
handle_event({key_release,_Sym,_Mod,_Code},_Sess,State) ->
    {noreply, State};
handle_event(Event={mousedown,Button,{X,Y,_}},Sess,State) ->
    if Button =:= 0 ->
	    %% locate an active widget at position (X,Y)
	    Ws = State#state.widgets,
	    case widgets_at_location(Ws,X,Y) of
		[] ->
		    {noreply, State};
		[W|_] ->  %% z-sort ?
		    case widget_event(Event, W, Sess, State) of
			W -> 
			    {noreply, State};
			W1 ->
			    ID = W1#widget.id,
			    Active = [ID | State#state.active],
			    Ws1 = dict:store(ID, W1, Ws),
			    {noreply, State#state { active = Active,
						    widgets = Ws1}}
		    end
	    end;
       true ->
	    {noreply, State}
    end;
handle_event(Event={mouseup,Button,{_X,_Y,_}},Sess,State) ->
    if Button =:= 0 ->
	    %% release "all" active widgets
	    State1 = 
		lists:foldl(
		  fun(ID, Si) ->
			  Ws = Si#state.widgets,
			  case dict:find(ID, Ws) of
			      error -> Si;
			      {ok,W} ->
				  case widget_event(Event, W, Sess, Si) of
				      W -> Si; %% no changed
				      W1 ->
					  Ws1 = dict:store(W1#widget.id,W1,Ws),
					  Si#state { widgets = Ws1}
				  end
			  end
		  end, State, State#state.active),
	    {noreply, State1#state { active = [] }};
       true ->
	    {noreply, State}
    end;
handle_event(Event={motion,Button,{X,Y,_}},Sess,State) ->
    if Button =:= 0 ->
	    %% locate an active widget at position (X,Y)
	    Ws = State#state.widgets,
	    case widgets_at_location(Ws,X,Y) of
		[] ->
		    {noreply, State};
		[W|_] ->
		    case widget_event(Event, W, Sess, State) of
			W -> {noreply, State}; %% no changed
			W1 ->
			    Ws1 = dict:store(W1#widget.id, W1, Ws),
			    {noreply, State#state { widgets = Ws1}}
		    end
	    end;
       true ->
	    {noreply, State}
    end;
handle_event(_Event,_Sess,State) ->
    lager:error("unknown event: ~p", [_Event]),
    {noreply, State}.

%%
%% Find all widgets in window WinID that is hit by the 
%% point (X,Y).
%%
widgets_at_location(Ws,X,Y) ->
    dict:fold(
      fun(_ID,W,Acc) ->
	      if X >= W#widget.x, Y >= W#widget.y,
		 X =< W#widget.x + W#widget.width - 1,
		 Y =< W#widget.y + W#widget.height - 1 ->
		      [W|Acc];
		 true ->
		      Acc
	      end
      end, [], Ws).

%% generate a callback event and start animate the button
widget_event({mousedown,_Button,Where}, W, _Sess, State) ->
    case W#widget.type of
	button ->
	    callback_all(W#widget.id, State#state.subs, [{value,1}]),
	    widget_animate_begin(W#widget { state=active }, press);
	slider ->
	    {X,_,_} = Where,
	    case widget_slider_value(W, X) of
		{ok,Value} ->
		    %% epx:window_enable_events(Window#widget.win, [motion]),
		    callback_all(W#widget.id,State#state.subs,[{value,Value}]),
		    self() ! refresh,
		    W#widget { state=active, value = Value };
		false ->
		    lager:debug("slider min/max/width error"),
		    W
	    end;
	_ ->
	    W
    end;
widget_event({mouseup,_Button,_Where}, W, _Sess, State) ->
    case W#widget.type of
	button ->
	    callback_all(W#widget.id, State#state.subs, [{value,0}]),
	    widget_animate_begin(W#widget{state=normal}, release);
	slider ->
	    %% epx:window_disable_events(Window#widget.win, [motion]),
	    W#widget{state=normal};
	_ ->
	    W
    end;
widget_event({motion,_Button,Where}, W, _Sess, State) ->
    case W#widget.type of
	slider ->
	    {X,_,_} = Where,
	    case widget_slider_value(W, X) of
		{ok,Value} ->
		    callback_all(W#widget.id,State#state.subs,[{value,Value}]),
		    self() ! refresh,
		    W#widget { value = Value };
		false ->
		    W
	    end;
	_ ->
	    W
    end;
widget_event(_Event, W, _Window, _State) ->
    W.

%% given x coordinate calculate the slider value
widget_slider_value(W=#widget { min=Min, max=Max }, X) ->
    Width = W#widget.width-2,
    if is_number(Min), is_number(Max), Width > 0 ->
	    X0 = W#widget.x+1,
	    X1 = X0 + Width - 1,
	    Xv = clamp(X, X0, X1),
	    R = (Xv - X0) / (X1 - X0),
	    {ok,trunc(Min + R*(Max - Min))};
       true ->
	    false
    end.

widget_animate_begin(W, press) ->
    lager:debug("animate_begin: down"),
    self() ! refresh,
    W#widget { animate = {color,{sub,16#00333333}} };
widget_animate_begin(W, release) ->
    lager:debug("animate_begin: up"),
    self() ! refresh,
    W#widget { animate = undefined };
widget_animate_begin(W, flash) ->
    lager:debug("animate_begin"),
    Anim = {flash,0,10},
    erlang:start_timer(0, self(),{animate,W#widget.id,Anim}),
    W#widget { animate = {color,{interpolate,0.0,16#00ffffff}}}.

widget_animate_end(W, flash) ->
    lager:debug("animate_end"),
    W#widget { animate = undefined }.

widget_animate_run(W, {flash,N,N}) ->
    widget_animate_end(W, flash);
widget_animate_run(W, {flash,I,N}) ->
    lager:debug("animate flash ~w of ~w", [I, N]),
    Anim = {flash,I+1,N},
    erlang:start_timer(30, self(),{animate,W#widget.id,Anim}),
    case W#widget.animate of
	{color,{interpolate,_V,AColor}} ->
	    W#widget { animate = {color,{interpolate,(I+1)/N,AColor}}};
	_ ->
	    W
    end.

callback_all(Wid, Subs, Env) ->
    lists:foreach(
      fun(#sub{id=ID,signal=Signal,callback=Callback}) ->
	      if ID =:= Wid ->
		      callback(Callback,Signal,Env);
		 true ->
		      ok
	      end
      end, Subs).

%% note that event signals may loopback be time consuming,
%% better to spawn them like this.
callback(undefined,_Signal,_Env)  ->
    ok;
callback(Cb,Signal,Env) when is_atom(Cb) ->
    spawn(fun() -> Cb:event(Signal, Env) end);
callback(Cb,Signal,Env) when is_function(Cb, 2) ->
    spawn(fun() -> Cb(Signal,Env) end).


lookup_widget(Flags, State) ->
    case lists:keyfind(id, 1, Flags) of
	false ->
	    {error,missing_id};
	{id,ID} ->
	    case dict:find(ID, State#state.widgets) of
		error ->
		    {error,enoent};
		{ok,W} ->
		    {ok,W}
	    end
    end.


widget_set([Option|Flags], W) ->
    case Option of
	{type,Type} when is_atom(Type) -> 
	    widget_set(Flags, W#widget{type=Type});
	{id,ID} when is_atom(ID) -> 
	    widget_set(Flags, W#widget{id=ID});
	{x,X} when is_integer(X) ->
	    widget_set(Flags, W#widget{x=X});
	{y,Y} when is_integer(Y) ->
	    widget_set(Flags, W#widget{y=Y});
	{width,Width} when is_integer(Width), Width>=0 ->
	    widget_set(Flags, W#widget{width=Width});
	{height,Height} when is_integer(Height), Height>=0 ->
	    widget_set(Flags, W#widget{height=Height});
	{text,Text} when is_list(Text) ->
	    widget_set(Flags, W#widget{text=Text});
	{image,File} when is_list(File) ->
	    widget_set(Flags, W#widget{image=File});
	{font, Spec} when is_list(Spec) ->
	    F0 = [ [case Key of
			size -> integer_to_list(Val)++"px";
			name -> Val;
			_ -> io_lib:format("~p", [Val])
		    end, " "] || {Key,Val} <- Spec ],
	    Font = lists:flatten(F0),
	    widget_set(Flags, W#widget{font=Font});
	{color,Color} when is_integer(Color), Color>=0 ->
	    widget_set(Flags, W#widget{color=Color});
	{fill, Style} when is_atom(Style) ->
	    widget_set(Flags, W#widget{fill=Style});
	{events,Es} when is_list(Es) ->
	    widget_set(Flags, W#widget{events=Es});
	{halign,A} when A =:= left;
			A =:= right;
			A =:= center->
	    widget_set(Flags, W#widget{halign=A});
	{valign,A} when A =:= top;
			A =:= bottom;
			A =:= center->
	    widget_set(Flags, W#widget{valign=A});
	{min,Min} when is_number(Min) ->
	    V = clamp(W#widget.value, Min, W#widget.max),
	    widget_set(Flags, W#widget{value=V,min=Min});
	{max,Max} when is_number(Max) ->
	    V = clamp(W#widget.value, W#widget.min, Max),
	    widget_set(Flags, W#widget{value=V,max=Max});
	{value,V} when is_number(V) ->
	    V1 = clamp(V, W#widget.min, W#widget.max),
	    widget_set(Flags, W#widget{value=V1});
	{format,F} when is_list(F) ->
	    widget_set(Flags, W#widget{format=F});
	_ ->
	    lager:debug("option ignored ~p", [Option]),
	    widget_set(Flags, W)
    end;
widget_set([], W) ->
    W.

redraw_schedule(State) ->
    if is_reference(State#state.redraw_timer) ->
	    State;
       State#state.redraw_timer =:= undefined ->
	    Timer = erlang:start_timer(50, self(), redraw),
	    State#state { redraw_timer = Timer }
    end.

redraw_state(State) ->
    lists:foreach(fun(Session) -> redraw_session(Session, State) end,
		  State#state.sessions),
    State.

redraw_session(#session { ws=Ws, canvas=Canvas }, State) ->
    wse:call(Ws, Canvas, clearRect, [0,0,320,240]),
    each_widget(fun(W) -> draw_widget(W, Ws, Canvas) end, State),
    wse:call(Ws, Canvas, swap, []),
    State.

each_widget(Fun, State) ->
    dict:fold(fun(_K,W,_) -> Fun(W) end, [], State#state.widgets),
    ok.

%% http://www.w3schools.com/tags/ref_canvas.asp
draw_widget(W, Ws, Canvas) ->
    case W#widget.type of
	window ->
	    %% do not draw (yet), we may use this
	    %% to draw embedded windows in the future
	    ok;
	button ->
	    draw_text_box(Ws, Canvas, W, W#widget.text);
	slider ->
	    set_color(Ws,Canvas,W),
	    wse:call(Ws,Canvas,fillRect,
		     [W#widget.x, W#widget.y,
		      W#widget.width, W#widget.height]),
	    set_canvas_color(Ws,Canvas,16#000000),
	    wse:call(Ws,Canvas,strokeRect,
		     [W#widget.x, W#widget.y,
		      W#widget.width, W#widget.height]),
	    %% draw value bar
	    #widget { min=Min, max=Max, value=Value} = W,
	    if is_number(Min),is_number(Max),is_number(Value) ->
		    Delta = abs(Max - Min),
		    R = if Min < Max ->
				V = if Value < Min -> Min;
				       Value > Max -> Max;
				       true -> Value
				    end,
				(V - Min)/Delta;
			   Min > Max -> %% reversed axis
				V = if Value > Min -> Min;
				       Value < Max -> Max;
				       true -> Value
				    end,
				(V - Max)/Delta;
			   true ->
				0.5
			end,
		    %% draw value marker
		    Wm = 3,    %% marker width
		    X = trunc(W#widget.x + R*((W#widget.width-Wm)-1)),
		    Y = W#widget.y + 2,
		    set_canvas_color(Ws,Canvas,16#000000),
		    wse:call(Ws,Canvas,fillRect,
			     [X, Y, Wm, W#widget.height-4]);
	       true ->
		    ok
	    end;

	value ->
	    Value = W#widget.value,
	    Format = W#widget.format,
	    Text = 
		if Value =:= undefined ->
			"-";
		   Format =:= undefined ->
			if is_integer(Value) ->
				integer_to_list(Value);
			   is_float(Value) ->
				io_lib_format:fwrite_g(Value);
			   true ->
				"?"
			end;
		   true ->
			lists:flatten(io_lib:format(Format,[Value]))
		end,
	    draw_text_box(Ws, Canvas, W, Text);

	rectangle ->
	    set_color(Ws,Canvas,W),
	    case W#widget.fill of
		blend ->
		    wse:call(Ws,Canvas,globalCompositeOperation,
			     [lighter]),
		    wse:call(Ws,Canvas,fillRect,
			     [W#widget.x, W#widget.y,
			      W#widget.width, W#widget.height]),
		    wse:call(Ws,Canvas,globalCompositeOperation,
			     ['source-over']);
		solid ->
		    wse:call(Ws,Canvas,fillRect,
			     [W#widget.x, W#widget.y,
			      W#widget.width, W#widget.height]);
		none ->
		    wse:call(Ws,Canvas,strokeRect,
			     [W#widget.x, W#widget.y,
			      W#widget.width, W#widget.height])
	    end;

	ellipse ->
	    set_color(Ws,Canvas,W),
	    A = W#widget.width div 2,
	    B = W#widget.height div 2,
	    R = min(A,B),
	    X = W#widget.x + A,
	    Y = W#widget.y + B,
	    wse:call(Ws, Canvas, beginPath, []),
	    wse:call(Ws, Canvas, arc, [X,Y,R,0.0,2*math:pi(),false]),
	    wse:call(Ws, Canvas, closePath, []),
	    case W#widget.fill of
		blend ->
		    wse:call(Ws,Canvas,globalCompositeOperation,
			     [lighter]),
		    wse:call(Ws, Canvas, fill, []),
		    wse:call(Ws,Canvas,globalCompositeOperation,
			     ['source-over']);
		solid ->
		    wse:call(Ws, Canvas, fill, []);
		none ->
		    wse:call(Ws, Canvas, stroke, [])
	    end;

	line ->
	    set_color(Ws,Canvas,W),
	    wse:call(Ws, Canvas, moveTo, [W#widget.x, W#widget.y]),
	    wse:call(Ws, Canvas, lineTo, [W#widget.x+W#widget.width-1,
					  W#widget.y+W#widget.height-1]),
	    wse:call(Ws, Canvas, stroke, []);
	%% image ->
	%%     epx_gc:draw(
	%%       fun() ->
	%% 	      if is_record(W#widget.image, epx_pixmap) ->
	%% 		      Width = epx:pixmap_info(W#widget.image,width),
	%% 		      Height = epx:pixmap_info(W#widget.image,height),
	%% 		      epx:pixmap_copy_area(W#widget.image,
	%% 					   Win#widget.image,
	%% 					   0, 0,
	%% 					   W#widget.x, W#widget.y,
	%% 					   Width, Height,
	%% 					   [solid]);
	%% 		 true ->
	%% 		      ok
	%% 	      end
	%%       end);
	text ->
	    draw_text_box(Ws, Canvas, W, W#widget.text);
	Type ->
	    lager:debug("bad widget type ~p", [Type])
    end.

%% draw widget button/value with centered text
draw_text_box(Ws, Canvas, W, Text) ->
    set_color(Ws,Canvas,W),
    case W#widget.fill of
	blend ->
	    wse:call(Ws,Canvas,globalCompositeOperation,
		     [lighter]),
	    wse:call(Ws,Canvas,fillRect,
		     [W#widget.x, W#widget.y,
		      W#widget.width, W#widget.height]),
	    wse:call(Ws,Canvas,globalCompositeOperation,
		     ['source-over']);
	solid ->
	    wse:call(Ws,Canvas,fillRect,
		     [W#widget.x, W#widget.y,
		      W#widget.width, W#widget.height]);
	none ->
	    wse:call(Ws,Canvas,strokeRect,
		     [W#widget.x, W#widget.y,
		      W#widget.width, W#widget.height])
    end,
    Xd = case W#widget.halign of
	     left  -> 0;
	     right -> W#widget.width;
	     center -> W#widget.width div 2
	 end,
    Yd = case W#widget.valign of
	     top -> 0;
	     bottom -> W#widget.height;
	     center -> W#widget.height div 2
	 end,
    X = W#widget.x + Xd,
    Y = W#widget.y + Yd,
    wse:call(Ws,Canvas,font,[W#widget.font]),
    %% black text color (fixme)
    wse:call(Ws,Canvas,fillStyle,[web_color(16#00000)]),
    wse:call(Ws,Canvas,textAlign,[W#widget.halign]),
    wse:call(Ws,Canvas,fillText,[Text,X,Y,W#widget.width]).


%% set foreground / fillcolor also using animatation state
set_color(Wse,Canvas,W) ->
    Color0 = W#widget.color,
    Color = case W#widget.animate of
		{color,{add,AColor}} ->
		    color_add(Color0, AColor);
		{color,{sub,AColor}} ->
		    color_sub(Color0, AColor);
		{color,{interpolate,V,AColor}} ->
		    %% color from AColor -> W#widget.color
		    color_interpolate(V, AColor, Color0);
		_ -> Color0
	    end,
    set_canvas_color(Wse,Canvas,Color).

set_canvas_color(Wse,Canvas,Color) ->
    wse:call(Wse,Canvas,strokeStyle,[web_color(Color)]),
    wse:call(Wse,Canvas,fillStyle,[web_color(Color)]).


color_add(C1, C2) ->
    <<C3:32>> = color_add_argb(<<C1:32>>, <<C2:32>>),
    C3.

color_sub(C1, C2) ->
    <<C3:32>> = color_sub_argb(<<C1:32>>, <<C2:32>>),
    C3.

color_interpolate(V, C1, C2) ->
    <<C3:32>> = color_interpolate_argb(V, <<C1:32>>, <<C2:32>>),
    C3.

color_add_argb(<<A1,R1,G1,B1>>,<<A2,R2,G2,B2>>) ->
    A = A1 + A2,
    R = R1 + R2,
    G = G1 + G2,
    B = B1 + B2,
    <<(clamp_byte(A)),(clamp_byte(R)),(clamp_byte(G)),(clamp_byte(B))>>.

color_sub_argb(<<A1,R1,G1,B1>>,<<A2,R2,G2,B2>>) ->
    A = A1 - A2,
    R = R1 - R2,
    G = G1 - G2,
    B = B1 - B2,
    <<(clamp_byte(A)),(clamp_byte(R)),(clamp_byte(G)),(clamp_byte(B))>>.

color_interpolate_argb(V, <<A0,R0,G0,B0>>,<<A1,R1,G1,B1>>) 
  when is_float(V), V >= 0.0, V =< 1.0 ->
    A = trunc(A0 + V*(A1-A0)),
    R = trunc(R0 + V*(R1-R0)),
    G = trunc(R1 + V*(G1-G0)),
    B = trunc(B1 + V*(B1-B0)),
    <<(clamp_byte(A)),(clamp_byte(R)),(clamp_byte(G)),(clamp_byte(B))>>.

web_color(Color) ->
    Color1 = Color band 16#ffffff,  %% strip alpha, not used here
    [$#|tl(integer_to_list(Color1+16#1000000, 16))].
    
clamp_byte(A) when A > 255 -> 255;
clamp_byte(A) when A < 0  -> 0;
clamp_byte(A) -> A.

%% clamp numbers
clamp(V,Min,Max) when is_number(V),is_number(Min),is_number(Max) ->
    if Min < Max -> min(max(V,Min), Max);
       Min > Max -> max(min(V,Min), Max);
       Min == Max -> Min
    end;
clamp(undefined,Min,Max) ->
    if is_number(Min) -> Min;
       is_number(Max) -> Max;
       true -> undefined
    end;
clamp(V,Min,undefined) when is_number(Min), V < Min -> Min;
clamp(V,undefined,Max) when is_number(Max), V > Max -> Max;
clamp(V,_,_) -> V.
