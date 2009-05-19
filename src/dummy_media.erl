%%	The contents of this file are subject to the Common Public Attribution
%%	License Version 1.0 (the “License”); you may not use this file except
%%	in compliance with the License. You may obtain a copy of the License at
%%	http://opensource.org/licenses/cpal_1.0. The License is based on the
%%	Mozilla Public License Version 1.1 but Sections 14 and 15 have been
%%	added to cover use of software over a computer network and provide for
%%	limited attribution for the Original Developer. In addition, Exhibit A
%%	has been modified to be consistent with Exhibit B.
%%
%%	Software distributed under the License is distributed on an “AS IS”
%%	basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%	License for the specific language governing rights and limitations
%%	under the License.
%%
%%	The Original Code is Spice Telephony.
%%
%%	The Initial Developers of the Original Code is 
%%	Andrew Thompson and Micah Warren.
%%
%%	All portions of the code written by the Initial Developers are Copyright
%%	(c) 2008-2009 SpiceCSM.
%%	All Rights Reserved.
%%
%%	Contributor(s):
%%
%%	Andrew Thompson <athompson at spicecsm dot com>
%%	Micah Warren <mwarren at spicecsm dot com>
%%

%% @doc A dummy media process designed to aid testing by mimicking a real call media process.

-module(dummy_media).
-author(micahw).

-behaviour(gen_server).

-ifdef(EUNIT).
-include_lib("eunit/include/eunit.hrl").
-endif.
-include_lib("stdlib/include/qlc.hrl").

-include("log.hrl").
-include("queue.hrl").
-include("call.hrl").
-include("agent.hrl").

-define(MEDIA_ACTIONS, [ring_agent, get_call, start_cook, voicemail, announce, stop_cook, oncall]).

%% API
-export([
	start_link/1,
	start_link/2,
	start/1,
	start/2,
	ring_agent/2,
	stop/1,
	stop/2,
	set_mode/3,
	%set_skills/2,
	%set_brand/2,
	q/0,
	q/1,
	q_x/1,
	q_x/2
	]).

%% gen_media callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, handle_ring/3, handle_answer/3, handle_voicemail/1, handle_announce/2, handle_ring_stop/1
]).

-ifndef(R13B).
-type(dict() :: any()).
-endif.

-record(state, {
	callrec = #call{} :: #call{},
	%mode = success :: 'success' | 'failure' | 'fail_once',
	fail = dict:new() :: dict()
	}).

%%====================================================================
%% API
%%====================================================================
start_link([H | _Tail] = Props) when is_tuple(H) ->
	start_link(Props, success);
start_link(Callid) ->
	start_link([{id, Callid}], success).

start_link(Props, success) ->
	gen_media:start_link(?MODULE, [Props, success]);
start_link(Props, failure) ->
	gen_media:start_link(?MODULE, [Props, failure]);
start_link(Props, Fails) when is_list(Fails) ->
	gen_media:start_link(?MODULE, [Props, Fails]).

start([H | _Tail] = Props) when is_tuple(H) ->
	start(Props, success);
start(Callid) ->
	start([{id, Callid}], success).

start(Props, success) ->
	gen_media:start(?MODULE, [Props, success]);
start(Props, failure) ->
	gen_media:start(?MODULE, [Props, failure]);
start(Props, Fails) when is_list(Fails) ->
	gen_media:start(?MODULE, [Props, Fails]).

stop(Pid) -> 
	stop(Pid, normal).

stop(Pid, Reason) ->
	gen_media:call(Pid, {stop, Reason}).

ring_agent(Pid, Agentpid) when is_pid(Pid), is_pid(Agentpid) -> 
	gen_media:call(Pid, {ring_agent, Agentpid}).
	
set_mode(Pid, Action, Mode) ->
	gen_media:call(Pid, {set_action, Action, Mode}).


%set_skills(Pid, Skills) ->
%	gen_media:call(Pid, {set_skills, Skills}).
%
%set_brand(Pid, Brand) ->
%	gen_media:call(Pid, {set_brand, Brand}).
	
q() ->
	q("default_queue").

q(Queuename) ->
	{ok, Dummypid} = start_link([{id, erlang:ref_to_list(make_ref())}]),
	Qpid = queue_manager:get_queue(Queuename),
	{call_queue:add(Qpid, Dummypid), Dummypid}.

q_x(N) ->
	F = fun() ->
		QH = qlc:q([Queue#call_queue.name || Queue <- mnesia:table(call_queue)]),
		qlc:e(QH)
	end,
	{atomic, Qs} = mnesia:transaction(F),
	?INFO("~p", [Qs]),
	q_x(N, Qs).

q_x(N, Queues) ->
	F = fun(_I) ->
		Index = crypto:rand_uniform(1, length(Queues) + 1),
		Q = lists:nth(Index, Queues),
		q(Q)
	end,
	lists:foreach(F, lists:seq(1, N)).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([Props, Fails]) ->
	process_flag(trap_exit, true),
	Proto = #call{id = "dummy", source = self(), ring_path = inband, media_path = inband},
	Callrec = build_call_rec(Props, Proto),
	Newfail = case Fails of
		success ->
			lists:map(fun(E) -> {E, success} end, ?MEDIA_ACTIONS);
		failure ->
			lists:map(fun(E) -> {E, fail} end, ?MEDIA_ACTIONS);
		_Other when is_list(Fails) ->
			F = fun(E) ->
				{E, fail}
			end,
			lists:map(F, Fails)
	end,
	{ok, {#state{callrec = Callrec, fail = dict:from_list(Newfail)}, Callrec}}.

	
	
%	Newfail = lists:map(fun(E) -> {E, success} end, ?MEDIA_ACTIONS),
%	Callrec = #call{id=Callid, source=self(), media_path = inband, ring_path = inband},
%	%cdr:cdrinit(Callrec),
%	{ok, {#state{callrec = Callrec, fail = dict:from_list(Newfail)}, Callrec}};
%init([Props, failure]) ->
%	process_flag(trap_exit, true),
%	Newfail = lists:map(fun(E) -> {E, fail} end, ?MEDIA_ACTIONS),
%	Callrec = #call{id=Callid, source=self(), media_path = inband, ring_path = inband},
%	{ok, {#state{callrec = Callrec, fail = dict:from_list(Newfail)}, Callrec}};
%init([Props, Fails]) when is_list(Fails) ->
%	process_flag(trap_exit, true),
%	F = fun(E) ->
%		{E, fail}
%	end,
%	Newfails = lists:map(F, Fails),
%	Callrec = #call{id=Callid, source=self(), media_path = inband, ring_path = inband},
%	{ok, {#state{callrec = Callrec, fail = Newfails}, Callrec}}.
		
%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%--------------------------------------------------------------------

handle_call(set_success, _From, #state{fail = Fail} = State) -> 
	Newfail = dict:map(fun(_Key, _Value) -> success end, Fail),
	{reply, ok, State#state{fail = Newfail}};
handle_call(set_failure, _From, #state{fail = Fail} = State) -> 
	Newfail = dict:map(fun(_Key, _Value) -> fail end, Fail),
	{reply, ok, State#state{fail = Newfail}};
%handle_call(set_fail_once, _From, State) ->
%	{reply, ok, State#state{mode = fail_once}};
handle_call({set_action, Action, fail}, _From, #state{fail = Curfail} = State) ->
	Newfails = dict:store(Action, fail, Curfail),
	{reply, ok, State#state{fail = Newfails}};
handle_call({set_action, Action, success}, _From, #state{fail = Curfail} = State) ->
	Newfail = dict:store(Action, success, Curfail),
	{reply, ok, State#state{fail = Newfail}};
handle_call({set_action, Action, fail_once}, _From, #state{fail = Curfail} = State) ->
	Newfail = dict:store(Action, fail_once, Curfail),
	{reply, ok, State#state{fail = Newfail}};
%handle_call({set_skills, Skills}, _From, #state{callrec = Call} = State) ->
%	{reply, ok, State#state{callrec = Call#call{skills=Skills}}};
%handle_call({set_brand, Brand}, _From, #state{callrec = Call} = State) ->
%	{reply, ok, State#state{callrec = Call#call{client=Brand}}};
%handle_call({ring_agent, AgentPid, Queuedcall, Ringout}, _From, #state{fail = Fail} = State) -> 
%	case dict:fetch(ring_agent, Fail) of
%		success -> 
%			timer:apply_after(Ringout, gen_server, cast, [Queuedcall#queued_call.cook, {stop_ringing, AgentPid}]),
%			Callrec = State#state.callrec,
%			{reply, agent:set_state(AgentPid, ringing, Callrec#call{cook = Queuedcall#queued_call.cook}), State};
%		fail -> 
%			{reply, invalid, State};
%		fail_once ->
%			Newfail = dict:store(ring_agent, success, Fail),
%			{reply, invalid, State#state{fail = Newfail}}
%	end;
%handle_call(get_call, _From, #state{fail = Fail} = State) -> 
%	case dict:fetch(get_call, Fail) of
%		success -> 
%			{reply, State#state.callrec, State};
%		fail -> 
%			{reply, invalid, State};
%		fail_once ->
%			Newfail = dict:store(get_call, success, Fail),
%			{reply, invalid, State#state{fail = Newfail}}
%	end;
handle_call({start_cook, Recipe, Queuename}, _From, #state{callrec = Call, fail = Fail} = State) -> 
	case dict:fetch(start_cook, Fail) of
		fail -> 
			{reply, invalid, State};
		success -> 
			{ok, Pid} = cook:start_link(self(), Recipe, Queuename),
			NewCall = Call#call{cook = Pid},
			{reply, ok, State#state{callrec = NewCall}};
		fail_once ->
			Newfail = dict:store(start_cook, success, Fail),
			{reply, invalid, State#state{fail = Newfail}}
	end;
handle_call({stop, Reason}, _From, State) ->
	{stop, Reason, ok, State};
handle_call(stop_cook, _From, #state{callrec = Call, fail = Fail} = State) -> 
	case dict:fetch(stop_cook, Fail) of
		success -> 
			case Call#call.cook of
				undefined -> 
					{reply, ok, State};
				Cookpid when is_pid(Cookpid) ->
					Cookres = cook:stop(Cookpid),
					NewCall = Call#call{cook = undefined},
					{reply, Cookres, State#state{callrec = NewCall}}
			end;
		fail -> 
			{reply, invalid, State};
		fail_once ->
			Newfail = dict:store(stop_cook, success, Fail),
			{reply, invalid, State#state{fail = Newfail}}
%	end;
	end.
%handle_call(voicemail, _From, #state{fail = Fail} = State) ->
%	case dict:fetch(voicemail, Fail) of
%		success ->
%			{reply, ok, State};
%		fail ->
%			{reply, invalid, State};
%		fail_once ->
%			Newfail = dict:store(voicemail, success, Fail),
%			{reply, invalid, State#state{fail = Newfail}}
%	end;
%handle_call({announce, _Args}, _From, #state{fail = Fail} = State) ->
%	case dict:fetch(announce, Fail) of
%		success -> 
%			{reply, ok, State};
%		fail ->
%			{reply, invalid, State};
%		fail_once ->
%			Newfail = dict:store(announce, success, Fail),
%			{reply, invalid, State#state{fail = Newfail}}
%	end.
%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
	{noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info(Info, State) ->
	?DEBUG("Info: ~p", [Info]),
	{noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
	ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%% gen_media specific callbacks
handle_announce(_Annouce, State) ->
	{ok, State}.

handle_answer(Agent, Call, #state{fail = Fail} = State) ->
	case dict:fetch(oncall, Fail) of
		success ->
			%agent:set_state(Agent, oncall, Call),
			{ok, State};
		fail ->
			{error, dummy_fail, State};
		fail_once ->
			Newfail = dict:store(oncall, success, Fail),
			{error, dummy_fail, State#state{fail = Newfail}}
	end.

handle_ring(Agent, Call, #state{fail = Fail} = State) ->
	case dict:fetch(ring_agent, Fail) of
		success ->
			{ok, State};
		fail ->
			{invalid, State};
		fail_once ->
			Newfail = dict:store(ring_agent, success, Fail),
			{invalid, State#state{fail = Newfail}}
	end.

handle_voicemail(#state{fail = Fail} = State) ->
	case dict:fetch(voicemail, Fail) of
		fail_once ->
			Newfail = dict:store(voicemail, success, Fail),
			{invalid, State#state{fail = Newfail}};
		fail ->
			{invalid, State};
		_Other ->
			{ok, State}
	end.

handle_ring_stop(State) ->
	{ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------

build_call_rec([], Rec) ->
	Rec;
build_call_rec([{id, Id} | Tail], Rec) ->
	build_call_rec(Tail, Rec#call{id = Id});
build_call_rec([{type, Type} | Tail], Rec) ->
	build_call_rec(Tail, Rec#call{type = Type});
build_call_rec([{callerid, Id} | Tail], Rec) ->
	build_call_rec(Tail, Rec#call{callerid = Id});
build_call_rec([{source, Pid} | Tail], Rec) ->
	build_call_rec(Tail, Rec#call{source = Pid});
build_call_rec([{client, Client} | Tail], Rec) ->
	build_call_rec(Tail, Rec#call{client = Client});
build_call_rec([{skills, Skills} | Tail], Rec) ->
	build_call_rec(Tail, Rec#call{skills = Skills}).

-ifdef(EUNIT).

dummy_test_() -> 
	{foreach,
	fun() ->
		mnesia:stop(),
		mnesia:delete_schema([node()]),
		mnesia:create_schema([node()]),
		mnesia:start(),
		agent_auth:start(),
		ok
	end,
	fun(_Ok) ->
		agent_auth:stop()
	end,
	[
		{
			"Simple start",
			fun() -> 
				?assertMatch({ok, _Pid}, dummy_media:start("testcall"))
			end
		},
		{
			"Set agent ringing when set to success",
			fun() -> 
				{ok, Agentpid} = agent:start(#agent{login="testagent"}),
				agent:set_state(Agentpid, idle),
				{ok, Dummypid} = dummy_media:start("testcall"),
				?assertMatch(ok, gen_media:ring(Dummypid, Agentpid, #queued_call{media = Dummypid, id = "testcall"}, 4000))
			end
		},
		{
			"Set agent ringing when set to failure",
			fun() -> 
				{ok, Agentpid} = agent:start(#agent{login="testagent"}),
				agent:set_state(Agentpid, idle),
				{ok, Dummypid} = dummy_media:start([{id, "testcall"}], failure),
				?assertMatch(invalid, gen_media:ring(Dummypid, Agentpid, #queued_call{media=Dummypid, id = "testcall"}, 4000))
			end
		},
		{
			"Get call when set to success",
			fun() -> 
				{ok, Dummypid} = dummy_media:start("testcall"),
				Call = gen_media:get_call(Dummypid),
				?assertMatch("testcall", Call#call.id)
			end
		},
%		{
%			"Get call when set to failure",
%			fun() -> 
%				{ok, Dummypid} = dummy_media:start("testcall", failure),
%				?assertMatch(invalid, gen_media:get_call(Dummypid))
%				%?assertMatch(invalid, gen_server:call(Dummypid, get_call))
%			end
%		},
		{
			"Start cook when set to success",
			fun() -> 
				{ok, Dummypid} = dummy_media:start("testcall"),
				?assertMatch(ok, gen_media:call(Dummypid, {start_cook, ?DEFAULT_RECIPE, "testqueue"}))
			end
		},
		{
			"Start cook when set to fail",
			fun() -> 
				{ok, Dummypid} = dummy_media:start([{id, "testcall"}], failure),
				?assertMatch(invalid, gen_media:call(Dummypid, {start_cook, ?DEFAULT_RECIPE, "testqueue"}))
			end
		},
		{
			"Answer voicemail call when set to success",
			fun() ->
				{ok, Dummypid} = dummy_media:start("testcall"),
				?assertMatch(ok, gen_media:voicemail(Dummypid))
			end
		},
		{
			"Answer voicemail call when set to fail",
			fun() ->
				{ok, Dummypid} = dummy_media:start([{id, "testcall"}], failure),
				?assertMatch(invalid, gen_media:voicemail(Dummypid))
			end
		},
		{
			"Announce when set for success",
			fun() ->
				{ok, Dummypid} = dummy_media:start("testcall"),
				?assertMatch(ok, gen_media:announce(Dummypid, "Random data"))
			end
		},
		{
			"Announce when set to fail",
			fun() ->
				{ok, Dummypid} = dummy_media:start([{id, "testcall"}], failure),
				?assertMatch(ok, gen_media:announce(Dummypid, "Random data"))
			end
		}
	]
	}.

set_action_test_() ->
	{foreach,
	fun() ->
		Call = #queued_call{media = self(), id = "testcall"},
		Dict = dict:from_list([{oncall, "goober"}, {announce, "goober"}]),
		#state{fail = Dict, callrec = Call}
	end,
	fun(_Whatever) ->
		ok
	end,
	[fun(State) ->
		{"Setting everything to a success",
		fun() ->
			{reply, ok, Newstate} = handle_call(set_success, self(), State),
			Test = fun(Key, success, Acc) ->
					[true | Acc];
				(Key, _Other, Acc) ->
					[false | Acc]
			end,
			?assertEqual([true, true], dict:fold(Test, [], Newstate#state.fail))
		end}
	end,
	fun(State) ->
		{"Setting everything to a failure",
		fun() ->
			{reply, ok, Newstate} = handle_call(set_failure, self(), State),
			Test = fun(Key, fail, Acc) ->
					[true | Acc];
				(Key, _Other, Acc) ->
					[false | Acc]
			end,
			?assertEqual([true, true], dict:fold(Test, [], Newstate#state.fail))
		end}
	end,
	fun(State) ->
		{"setting a single action to fail",
		fun() ->
			{reply, ok, Newstate} = handle_call({set_action, oncall, fail}, self(), State),
			Test = fun(oncall, fail, Acc) -> 
					[true | Acc];
				(announce, "goober", Acc) ->
					[true | Acc];
				(Key, Val, Acc) ->
					[false, Acc]
			end,
			?assertEqual([true, true], dict:fold(Test, [], Newstate#state.fail))
		end}
	end,
	fun(State) ->
		{"Setting a single action to succeed",
		fun() ->
			{reply, ok, Newstate} = handle_call({set_action, oncall, success}, self(), State),
			Test = fun(oncall, success, Acc) ->
					[true | Acc];
				(announce, "goober", Acc) ->
					[true | Acc];
				(Key, Val, Acc) ->
					[false | Acc]
			end,
			?assertEqual([true, true], dict:fold(Test, [], Newstate#state.fail))
		end}
	end,
	fun(State) ->
		{"Setting a single action to fail_once",
		fun() ->
			{reply, ok, Newstate} = handle_call({set_action, oncall, fail_once}, self(), State),
			Test = fun(oncall, fail_once, Acc) ->
					[true | Acc];
				(announce, "goober", Acc) ->
					[true | Acc];
				(Key, Val, Acc) ->
					[false | Acc]
			end,
			?assertEqual([true, true], dict:fold(Test, [], Newstate#state.fail))
		end}
	end]}.

% Test if the action setting functions work.

%
%
%[{Action, Callback, Args, Testup, Testdown}]
%
%foreach action, using the given callback, ensure we get the correct responses
%on each set_action.
%
%-define(MEDIA_ACTION_PARAMS, [
%	{ring_agent, fun() ->
%		Call = #queued_call{media = self(), id = "testcall"},
%		{ok, Agentpid} = agent:start(#agent{login = "testagent"}),
%		agent:set_state(Agentpid, idle),
%		Fup = fun({ok, _Whatever}) -> true; (_Else) -> false end,
%		Fdown = fun({invalid, _Whatever}) -> true; (_Else) -> false end
%		{handle_ring, [Agentpid, Call], Fup, Fdown}},
%	{start_cook, fun() ->
%		{handle_call, [{start_cook, [], "testqueue"}, "wherever"

%-define(MEDIA_ACTION_PARAMS, [
%	{ring_agent, fun() ->
%		Queuedcall = #queued_call{media = self(), id = "testcall"},
%		{ok, Agentpid} = agent:start(#agent{login = "testagent"}),
%		agent:set_state(Agentpid, idle),
%		{ring_agent, Agentpid, Queuedcall, 1}
%	end},
%	{start_cook, fun() ->
%		{start_cook, recipe, "queuename"}
%	end},
%	{stop_cook, fun() ->
%		stop_cook
%	end},
%	{voicemail, fun() ->
%		voicemail
%	end},
%	{announce, fun() ->
%		{announce, "args"}
%	end}
%]).
%
%-define(SUCCESS_MODES, [{fail, invalid, invalid}, {fail_once, invalid, ok}, {success, ok, ok}]).
%
%success_test_() ->
%	{generator,
%	fun() ->
%		{ok, Dummypid} = dummy_media:start("testcall"),
%		Modes = fun({Mode, Test1, Test2}) ->
%			Paramed = fun({Action, Params}) ->
%				Nom = "Mode " ++ atom_to_list(Mode) ++ " for " ++ atom_to_list(Action),
%				{Nom,
%				fun() ->
%					dummy_media:set_mode(Dummypid, Action, Mode),
%					?assertEqual(Test1, gen_server:call(Dummypid, Params())),
%					?assertEqual(Test2, gen_server:call(Dummypid, Params()))
%				end}
%			end,
%			lists:map(Paramed, ?MEDIA_ACTION_PARAMS)
%		end,
%		Tests = lists:map(Modes, ?SUCCESS_MODES),
%		lists:append(Tests)
%	end}.
	
-endif.
