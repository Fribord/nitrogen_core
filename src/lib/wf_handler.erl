% vim: sw=4 ts=4 et ft=erlang
-module (wf_handler).
-include("wf.hrl").
-export ([
    init/1,
    finish/1,
    call/2, 
    call/3,
    call_readonly/2, 
    call_readonly/3,
    set_handler/2
]).


%% Because the handlers are all initialized and finished at the beginning and
%% end of requests together, rather than getting and setting each handler
%% individually from and to the process dictionary, we get them all in bulk,
%% then set them all in bulk in wf_core. So here we're just going to return the
%% raw handler context to be stored with the rest of the handler contexts.
-spec init(#handler_context{}) -> #handler_context{}.
init(H = #handler_context{module=Module, config=Config, state=State}) ->
    {ok, NewState} = Module:init(Config, State),
    H#handler_context{state=NewState}.

-spec finish(#handler_context{}) -> #handler_context{}.
finish(H = #handler_context{module=Module, config=Config, state=State}) ->
    {ok, NewState} = Module:finish(Config, State),
    H#handler_context{state=NewState}.

% Helper function to call a function within a handler.
% Returns ok or {ok, Value}.
call(Name, FunctionName) -> call(Name, FunctionName, []).

% Helper function to call a function within a handler.
% Returns ok or {ok, Value}.
call(Name, FunctionName, Args) ->
    % Get the handler and state from the context. Then, call
    % the function, passing in the Args and State.
    #handler_context { module=Module, config=Config, state=State } = get_handler(Name),
    Result = erlang:apply(Module, FunctionName, Args ++ [Config, State]),

    % Result will be {ok, State}, {ok, Value1, State}, or {ok, Value1, Value2, State}.
    % Update the context with the new state.
    case Result of
        {ok, NewState} -> 
            update_handler_state(Name, NewState),
            ok;

        {ok, Value, NewState} ->
            update_handler_state(Name, NewState),
            {ok, Value};

        {ok, Value1, Value2, NewState} ->
            update_handler_state(Name, NewState),
            {ok, Value1, Value2}
    end.

call_readonly(Name, FunctionName) -> call_readonly(Name, FunctionName, []).

call_readonly(Name, FunctionName, Args) ->
    % Get the handler and state from the context. Then, call
    % the function, passing in the Args with State appended.
    #handler_context { module=Module, config=Config, state=State } = get_handler(Name),
    erlang:apply(Module, FunctionName, Args ++ [Config, State]).

set_handler(Module, Config) ->
    {module, Module} = wf_utils:ensure_loaded(Module),

    % Get the module's behavior...
    L = Module:module_info(attributes),
    Name = case proplists:get_value(behaviour, L) of
        [N] -> N;
        _      -> throw({must_define_a_nitrogen_behaviour, Module})
    end,
    set_handler(Name, Module, Config).


% set_handler/3
% Set the configuration for a handler.
set_handler(Name, Module, Config) ->
    Handlers = wf_context:handlers(),
    OldHandler = lists:keyfind(Name, 2, Handlers),
    NewHandler = OldHandler#handler_context { module=Module, config=Config },
    NewHandlers = lists:keyreplace(Name, 2, Handlers, NewHandler),
    wf_context:handlers(NewHandlers).	

% get_handler/2 - 
% Look up a handler in a context. Return {ok, HandlerModule, State}
get_handler(Name) -> 
    Handlers = wf_context:handlers(),
    case lists:keysearch(Name, 2, Handlers) of
        {value, Handler} when is_record(Handler, handler_context) -> 
            Handler;
        false -> 
            throw({handler_not_found_in_context, Name, Handlers})
    end.


update_handler_state(Name, State) ->
    wf_context:increment(update_handler_state),
    Handlers = wf_context:handlers(),
    OldHandler = lists:keyfind(Name, 2, Handlers),
    NewHandler = OldHandler#handler_context { state=State },
    NewHandlers = lists:keyreplace(Name, 2, Handlers, NewHandler),
    wf_context:handlers(NewHandlers).
