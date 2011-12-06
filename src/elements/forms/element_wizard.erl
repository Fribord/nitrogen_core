% Nitrogen Web Framework for Erlang
% Copyright (c) 2008-2009 Rusty Klophaus
% See MIT-LICENSE for licensing information.

-module (element_wizard).
-include ("wf.hrl").
-compile(export_all).

reflect() -> record_info(fields, wizard).

render_element(Record = #wizard{}) -> 
	% Set up callbacks...
	Tag = Record#wizard.tag,

	%ControlID = wf:temp_id(),

	% Set up steps...
	wf:assert(Record#wizard.id /= undefined, wizard_needs_a_proper_name),
	wf:assert(is_list(Record#wizard.steps), wizard_steps_must_be_a_list),
	wf:assert(Record#wizard.titles == undefined orelse length(Record#wizard.titles) == length(Record#wizard.steps), wizard_incorrect_number_of_titles),
	StepCount = length(Record#wizard.steps),
	StepSeq = lists:seq(1, StepCount),
	StepIDs = [wf:to_atom("step" ++ integer_to_list(X)) || X <- StepSeq],
	
	% Function to create an individual step.
	F = fun(N) ->
		StepID = lists:nth(N, StepIDs),
		StepTitle = case Record#wizard.titles of
			undefined -> "";
			_ -> lists:nth(N, Record#wizard.titles)
		end,
		StepBody = lists:nth(N, Record#wizard.steps),
		IsFirst = (N == 1),
		IsLast = (N == length(StepIDs)),
		
		#panel { id=StepID, style="display: none;", body=[
			#singlerow { class="wizard_title", cells=[
				#tablecell { text=StepTitle },
				#tablecell { class="wizard_buttons_top", body=[
					#button { id=backTop, show_if=(not IsFirst), text="Back", postback={back, N, StepIDs}, delegate=?MODULE },
					#button { id=nextTop, show_if=(not IsLast), text="Next", postback={next, N, StepIDs}, delegate=?MODULE },
					#button { id=finishTop, show_if=IsLast, text="Finish", postback={finish, Tag}, delegate=?MODULE }				
				]}
			]},
			#panel { class="wizard_body", body=StepBody },
			#panel { class="wizard_buttons_bottom", body=[
				#button { id=back, show_if=(not IsFirst), text="Back", postback={back, N, StepIDs}, delegate=?MODULE },
				#button { id=next, show_if=(not IsLast), text="Next", postback={next, N, StepIDs}, delegate=?MODULE },
				#button { id=finish, show_if=IsLast, text="Finish", postback={finish, Tag}, delegate=?MODULE } 
			]}
		]}
	end,

	% Combine the steps.
	Terms = #panel {
		class="wizard " ++ wf:to_list(Record#wizard.class),
		body=[F(X) || X <- StepSeq] 
	},
	
	% Show the first step.
	sigma:log({open,hd(StepIDs)}),
	wf:wire(hd(StepIDs), #show{}),	
	
	% Render.
	Terms.
	
event({back, N, StepIDs}) -> 
	wf:wire(lists:nth(N, StepIDs), #hide {}),
	wf:wire(lists:nth(N - 1, StepIDs), #show {}),
	ok;	

event({next, N, StepIDs}) -> 
	wf:wire(lists:nth(N, StepIDs), #hide {}),
	wf:wire(lists:nth(N + 1, StepIDs), #show {}),
	ok;	

event({finish, Tag}) -> 
	Delegate = wf:page_module(),
	Delegate:wizard_event(Tag),
	ok;
	
event(_) -> ok.

combine(A, B) ->
	wf:to_list(A) ++ "_" ++ wf:to_list(B).
