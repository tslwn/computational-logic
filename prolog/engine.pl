%% engine: Question-answering module.
%
% This module provides the question-answering engine of the system.
%
:- module(engine, [
    prove_question/2,
    prove_question_list/2,
    prove_question_tree/2
  ]).

% --- Imports ---

:- use_module(library(debug)).
:- use_module(grammar).
:- use_module(sentence).
:- use_module(utils).

negation(negation(X)) :- X.

% --- Question Answering ---

%% prove_question(+Question:atom, -Output:string)
%
% The prove_question/2 predicate tries to prove a question from the known facts.
% If the question can be proved to be either true or false, it outputs the answer.
% Otherwise, it outputs a default response.
%
% @param +Question: The question to prove.
% @param -Output: The generated output.
%
prove_question(Question, Output) :-
  prove_question_list(Question, MaybeEmpty),
  (
    % If the question can be proved to be either true or false, output the answer.
    MaybeEmpty \= '' -> Output = MaybeEmpty
  ;
    % Otherwise, output a default response.
    Output = 'I do not know whether that is true or false.'
  ).

%% prove_question_list(+Question:atom, -Output:string)
%
% The prove_question_list/2 predicate tries to prove a question from the known facts.
% If the question can be proved to be either true or false, it outputs the answer.
% Otherwise, it outputs the empty string.
% It is suitable for use with maplist, such as in find_known_facts_noun/2.
%
% @param +Question: The question to prove.
% @param -Output: The generated output.
%

% -- Rule
prove_question_list((Head :- Body), Output) :-
  % Find all known facts.
  findall(Fact, utils:known_fact(Fact), FactList),
  (
    % Try to prove the question is true.
    engine:prove_from_known_facts(Head, Body, Certainty, FactList) ->
      engine:output_answer((Head :- Body | Certainty), Output)
  ;
    % If the question cannot be proved to be either true or false, output the empty string.
    Output = ''
  ).


% -- Negative
prove_question_list(negation(Question), Output) :-
  prove_question_list_internal(Question, Output).

% -- Positive
prove_question_list(Question, Output) :-
  prove_question_list_internal(Question, Output).

prove_question_list_internal(X, Output) :-
  % Find all known facts.
  findall(Fact, utils:known_fact(Fact), FactList),
  (
    % Try to prove X is true.
    engine:prove_from_known_facts(X, true, Certainty, FactList) ->
      engine:output_answer((X | Certainty), Output)
  ;
    % Try to prove X is false.
    engine:prove_from_known_facts(X, false, Certainty, FactList) ->
      engine:output_answer((negation(X) | Certainty), Output)
  ;
    % If X cannot be proved to be either true or false, output the empty string.
    Output = ''
  ).


%% prove_question_tree(+Question:atom, -Output:string)
%
% The prove_question_tree/2 predicate is an extended version of prove_question/2 that constructs a proof tree.
% If the question can be proved to be either true or false, it transforms each step of the proof into a
% sentence and concatenates the sentences into the output.
%
% @param +Question: The question to prove.
% @param -Output: The generated output.
%

% -- Rule
prove_question_tree((Head :- Body), Output) :-
  % Find all known facts.
  findall(Fact, utils:known_fact(Fact), FactList),
  (
    % Try to prove the question is true.
    engine:prove_from_known_facts(Head, Body, Certainty, FactList, [], ProofList) ->
      engine:output_proof_list((Head :- Body | Certainty), ProofList, Output)
  ;
    % If the question cannot be proved, output a default response.
    Output = 'I do not know whether that is true or false.'
  ).

% -- Negative
prove_question_tree(negation(Question), Output) :-
  prove_question_tree_internal(Question, Output).

% -- Positive
prove_question_tree(Question, Output) :-
  prove_question_tree_internal(Question, Output).

prove_question_tree_internal(X, Output) :-
  % Find all known facts.
  findall(Fact, utils:known_fact(Fact), FactList),
  (
    % Try to prove X is true.
    engine:prove_from_known_facts(X, true, Certainty, FactList, [], ProofList) ->
      engine:output_proof_list((X | Certainty), ProofList, Output)
  ;
    % Try to prove X is false.
    engine:prove_from_known_facts(X, false, Certainty, FactList, [], ProofList) ->
      engine:output_proof_list((negation(X) | Certainty), ProofList, Output)
  ;
    % If X cannot be proved, output a default response.
    Output = 'I do not know whether that is true or false.'
  ).

% --- Meta-interpreter ---

%% prove_from_known_facts(+Clause:atom, +TruthValue:atom, -Certainty:integer, +FactList:list, -ProofList:list, -Proof:atom)
%
% The prove_from_known_facts/4 predicate tries to prove a clause based on a list of facts.
% If the clause can be proved, it stores the proof in the output.
% The proof is a list of steps, where each step is a fact that was used to prove the clause.
%
% @param +Clause: The clause to prove.
% @param +TruthValue: The truth value of the clause (true or false).
% @param -Certainty: The accumulated certainty of the proof.
% @param +FactList: The list of facts to use.
% @param +ProofList: The accumulator for the proof.
% @param -Proof: The generated proof.
%

% Base case. The clause is the goal (with a certainty of 1).
prove_from_known_facts(Goal, Goal, 1, _FactList, ProofList, ProofList) :- !.

% -- Disjunction (positive). A disjunction is true if any of the disjuncts is true.
prove_from_known_facts((FirstClause; OtherClauses), true, Certainty, FactList, ProofList, Proof) :-
  debug:debug('engine', 'disjunctive question: trying to prove ~q is ~q', [FirstClause; OtherClauses, true]),
  (
    % Try to prove the first clause or...
    prove_from_known_facts(FirstClause, true, Certainty, FactList, [], A)
  ;
    % Try to prove the other clauses.
    prove_from_known_facts(OtherClauses, true, Certainty, FactList, [], B)
  ),

  append(A, B, C),
  append(C, ProofList, Proof),

  debug:debug('engine', 'disjunctive question: proved ~q is ~q', [(FirstClause; OtherClauses), true]).

% -- Disjunction (negative). A disjunction is false if all of the disjuncts are false.
prove_from_known_facts((FirstClause; OtherClauses), false, NewCertainty, FactList, ProofList, Proof) :-
  debug:debug('engine', 'disjunctive question: trying to prove ~q is ~q', [(FirstClause; OtherClauses), false]),

  % Try to prove the first clause and...
  prove_from_known_facts(FirstClause, false, FirstCertainty, FactList, [], A),
  % Try to prove the other clauses.
  prove_from_known_facts(OtherClauses, false, OtherCertainty, FactList, [], B),

  NewCertainty is min(FirstCertainty, OtherCertainty),

  append(A, B, C),
  append(C, ProofList, Proof),

  debug:debug('engine', 'disjunctive question: proved ~q is ~q', [(FirstClause; OtherClauses), false]).

% -- Conjunction (positive). A conjunction is is true if all of the conjuncts are true.
prove_from_known_facts((FirstClause, OtherClauses), true, NewCertainty, FactList, ProofList, Proof) :-
  debug:debug('engine', 'conjunctive question: trying to prove ~q is ~q', [(FirstClause, OtherClauses), true]),

  % Try to prove the first clause and...
  prove_from_known_facts((FirstClause), true, FirstCertainty, FactList, [], A),
  % Try to prove the other clauses.
  prove_from_known_facts((OtherClauses), true, OtherCertainty, FactList, [], B),

  NewCertainty is min(FirstCertainty, OtherCertainty),

  append(A, B, C),
  append(C, ProofList, Proof),

  debug:debug('engine', 'conjunctive question: proved ~q is ~q', [(FirstClause, OtherClauses), true]).

% -- Conjunction (negative). A conjunction is false if any of its conjuncts is false.
prove_from_known_facts((FirstClause, OtherClauses), false, Certainty, FactList, ProofList, Proof) :-
  debug:debug('engine', 'conjunctive question: trying to prove ~q is ~q', [(FirstClause, OtherClauses), false]),

  (
    % Try to prove the first clause or...
    prove_from_known_facts((FirstClause), false, Certainty, FactList, [], A)
  ;
    % Try to prove the other clauses.
    prove_from_known_facts((OtherClauses), false, Certainty, FactList, [], B)
  ),

  append(A, B, C),
  append(C, ProofList, Proof),

  debug:debug('engine', 'conjunctive question: proved ~q is ~q', [(FirstClause, OtherClauses), false]).

% -- Implication (modus ponens, positive)
prove_from_known_facts(Clause, true, NewCertainty, FactList, ProofList, Proof) :-
  debug:debug('engine', 'implication: trying to prove ~q is ~q', [Clause, true]),
  % Find a clause of the form 'if Body then Clause'.
  utils:find_clause((Clause :- Body | ClauseCertainty), Fact, FactList),
  debug:debug('engine', 'implication: found ~q :- ~q', [Clause, Body]),
  % Try to prove Body. If the proof succeeds, then we have proven Clause.
  prove_from_known_facts(Body, true, Certainty, FactList, [proof(Clause, Fact)|ProofList], Proof),
  NewCertainty is min(Certainty, ClauseCertainty).

% -- Implication (modus ponens, negative)
prove_from_known_facts(Clause, false, NewCertainty, FactList, ProofList, Proof) :-
  debug:debug('engine', 'implication: trying to prove ~q is ~q', [Clause, false]),
  % Find a clause of the form 'if Body then Clause'.
  utils:find_clause((negation(Clause) :- Body | ClauseCertainty), Fact, FactList),
  debug:debug('engine', 'implication: found ~q :- ~q', [negation(Clause), Body]),
  % Try to prove Body. If the proof succeeds, then we have proven Clause.
  prove_from_known_facts(Body, true, Certainty, FactList, [proof(Clause, Fact)|ProofList], Proof),
  NewCertainty is min(Certainty, ClauseCertainty).

% -- Implication (modus ponens) rule
prove_from_known_facts(Clause, Goal, NewCertainty, FactList, ProofList, Proof) :-
  debug:debug('engine', 'implication: trying to prove ~q is ~q', [Clause, Goal]),
  % Find a clause of the form 'if Body then Clause'.
  utils:find_clause((Clause :- Body | ClauseCertainty), Fact, FactList),
  debug:debug('engine', 'implication: found ~q :- ~q', [Clause, Body]),
  % Try to prove Body. If the proof succeeds, then we have proven Clause.
  prove_from_known_facts(Body, Goal, Certainty, FactList, [proof(Clause, Fact)|ProofList], Proof),
  NewCertainty is min(Certainty, ClauseCertainty).

% -- Negation (modus tollens)
prove_from_known_facts(Clause, false, NewCertainty, FactList, ProofList, Proof) :-
  debug:debug('engine', 'negation: trying to prove ~q is ~q', [Clause, false]),
  % If the clause we're trying to prove implies another fact, and we can prove that fact is false, then we can prove the clause is false.
  utils:find_clause((Head :- Clause | ClauseCertainty), Fact, FactList),
  debug:debug('engine', 'negation: found ~q :- ~q', [Head, Clause]),
  % Try to prove the negation of Body. If the proof succeeds, then we have proven the negation of Clause.
  prove_from_known_facts(negation(Head), true, Certainty, FactList, [proof(negation(Clause), Fact)|ProofList], Proof),
  NewCertainty is min(Certainty, ClauseCertainty).


% -- Disjunction
prove_from_known_facts(Clause, Goal, NewCertainty, FactList, ProofList, Proof) :-
  % Find a clause of the form 'clause1; clause2...'
  utils:find_clause((FirstClause; ClausesAfter :- Body | ClauseCertainty), Fact, FactList),

  debug:debug('engine', 'disjunction: trying to find ~q in ~q :- ~q', [Clause, (FirstClause; ClausesAfter), Body]),
  % Convert the (nested) disjuncts to a list and check the clause is one using member/2.
  utils:list_of_disjuncts((FirstClause; ClausesAfter), Disjuncts),
  member(Clause, Disjuncts),

  % Convert the other disjuncts back to a disjunctive clause so we can try to prove them.
  select(Clause, Disjuncts, OtherDisjuncts),
  utils:list_of_disjuncts(OtherClauses, OtherDisjuncts),

  debug:debug('engine', 'disjunction: found ~q :- ~q', [(FirstClause; ClausesAfter), Body]),

  % Try to prove Body is true. If the proof succeeds, then we know one and only one of
  % the disjuncts is true.
  prove_from_known_facts(Body, true, BodyCertainty, FactList, [], BodyProof),

  (
    % Try to disprove all other disjuncts (Goal = true); or
    Goal = true -> NotGoal = false
  ;
    % ...prove at least one other disjunct is true (Goal = false).
    NotGoal = true
  ),

  % When trying to prove the other disjuncts, we don't want to match with this
  % disjunction or the program will enter an infinite loop. So we remove this disjunction
  % from the fact list when trying to prove the other disjuncts.
  select([(FirstClause; ClausesAfter :- Body | _)], FactList, SubFactList),

  debug:debug('engine', 'disjunction: trying to prove ~q is ~q from ~q', [OtherClauses, NotGoal, SubFactList]),
  prove_from_known_facts(OtherClauses, NotGoal, Certainty, SubFactList, [], OtherClauseProofs),

  Z is min(ClauseCertainty, BodyCertainty),
  NewCertainty is min(Certainty, Z),

  % Concatenate the proofs of the Body, negation(Other), and Clause.
  append(BodyProof, OtherClauseProofs, DisjProof),
  append(DisjProof, ProofList, NewProofList),
  Proof = [proof(Clause, Fact)|NewProofList],

  debug:debug('engine', 'disjunction: proved ~q', [Clause]).


% -- Conjunction
prove_from_known_facts(Clause, Goal, NewCertainty, FactList, ProofList, Proof) :-
  % Find a clause of the form 'if Body then *one* of several things including Clause is true'.
  utils:find_clause((FirstClause, ClausesAfter :- Body | ClauseCertainty), Fact, FactList),

  % Convert the (nested) conjuncts to a list and check the clause is one using member/2.
  utils:list_of_conjuncts((FirstClause, ClausesAfter), Conjuncts),
  member(Clause, Conjuncts),

  debug:debug('engine', 'conjunction: found ~q :- ~q', [(FirstClause, ClausesAfter), Body]),

  % Try to prove Body is true. If the proof succeeds, then one and only one of the disjuncts is true.
  prove_from_known_facts(Body, Goal, BodyCertainty, FactList, [], BodyProof),

  NewCertainty is min(ClauseCertainty, BodyCertainty),

  % Concatenate the proofs.
  append(BodyProof, ProofList, A),
  Proof = [proof(Clause, Fact)|A],

  debug:debug('engine', 'conjunction: proved ~q', [Clause]).

% prove_from_known_facts(+Clause:atom, +Goal:atom, +FactList:list)

% The prove_from_known_facts/2 predicate also tries to prove a clause, but it does not
% store the proof, i.e. only the answer is needed.

% @param +Clause: The clause to prove.
% @param +Goal: The truth value of the clause (true or false) or another term e.g mortal(X).
% @param +FactList: The list of facts to use.

prove_from_known_facts(Clause, Goal, Certainty, FactList) :-
  prove_from_known_facts(Clause, Goal, Certainty, FactList, [], _Proof).

% --- Commands ---

%% find_known_facts(-Output:string)
%
% The find_known_facts/1 predicate finds all known facts and transforms the sentences
% into a string output.
%
% @param -Output: The known facts or default response.
%
find_known_facts(Output) :-
  % Find all known facts.
  findall(Fact, utils:known_fact(Fact), FactList),
  % Transform each fact into a response.
  maplist(engine:output_known_fact, FactList, OutputList),
  ( % If no facts are known, output a default response.
    OutputList = [] -> Output = 'I do not know anything.'
    % Otherwise, store the concatenated responses in the output.
  ; atomic_list_concat(OutputList, '. ', Output)
  ).

%% find_known_facts_noun(+ProperNoun:atom, -Output:string)
%
% The find_known_facts_noun/2 predicate finds all known facts with a proper-noun argument,
% and transforms the sentences into a string output.
%
% @param +ProperNoun: The proper noun.
% @param -Output: The known facts or default response.
%
find_known_facts_noun(ProperNoun, Output) :-
  findall(
    Question,
    ( % Find all predicates that take a single argument.
      grammar:predicate(Predicate, 1, _Words),
      % For each predicate, construct a question with the proper noun as its argument.
      Question=..[Predicate, ProperNoun]
    ),
    QuestionList
  ),
  % Try to prove each question in the list and store the responses (or empty strings).
  maplist(engine:prove_question_list, QuestionList, QuestionOutputList),
  % Remove questions that could not be proved from the list.
  delete(QuestionOutputList, '', OutputList),
  ( % If no questions could be proved, output a default response.
    OutputList = [] ->
      atomic_list_concat(['I do not know anything about', ProperNoun], ' ', Output)
  ; % Otherwise, store the concatenated responses in the output.
    otherwise ->
      atomic_list_concat(OutputList, '. ', Output)
  ).

% --- Facts ---

%% is_fact_known(+FactList:list)
%
% The is_fact_known/2 predicate checks if a fact is known.
% If the fact itself is not known, it tries to prove it based on the known facts.
%
% @param +FactList: The list of facts to check.
%
is_fact_known([Fact]) :-
  % Find all known facts.
  findall(Fact, utils:known_fact(Fact), FactListOld),
  % Try to prove the fact based on the known facts.
  utils:try((
      % Try to unify the free variables in the fact with anything else.
      numbervars(Fact, 0, _),
      % Construct a clause from the fact.
      Fact = (Head :- Body),
      % Add the body of the clause to the known facts.
      engine:add_clause_to_facts(Body, FactListOld, FactListNew),
      % Try to prove the head of the clause based on the known facts.
      engine:prove_from_known_facts(Head, true, _Certainty, FactListNew)
  )).

%% add_clause_to_facts(+Clause:atom, +FactListOld:list, -FactListNew:list)
%
% The add_clause_to_facts/3 predicate adds a clause to a list of facts.
%
% @param +Clause: The clause.
% @param +FactListOld: The list of facts to update.
% @param -FactListNew: The updated list of facts.
%

% Recursive case: If the clause is a conjunction, add each conjunct to the list of facts.
add_clause_to_facts((Conjunct1, Conjunct2), FactListOld, FactListNew) :-
  !,
  % Add the first conjunct to the list of facts.
  add_clause_to_facts(Conjunct1, FactListOld, FactListTemp),
  % Add the second conjunct to the list of facts.
  add_clause_to_facts(Conjunct2, FactListTemp, FactListNew).

% Base case: If the body is not a conjunction, add it to the list of facts.
add_clause_to_facts(Clause, FactList, [(Clause :- true)|FactList]).

%% output_answer(+Question:atom, -Output:string)
%
% The output_answer/2 predicate transforms a question answer into a string output.
%
% @param +Result: The question.
% @param -Output: The generated output.
%
output_answer(Question, Output) :-
  % Transform the question into a clause.
  utils:transform(Question, Clause),
  % Transform the clause into a sentence.
  phrase(sentence:sentence(Clause), OutputList),
  % Transform the sentence into a string.
  atomics_to_string(OutputList, ' ', Output).

%% output_known_fact(+Fact:atom, -Output:string)
%
% The output_known_fact/2 predicate transforms a known fact into a string output.
%
% @param +Fact: The known fact.
% @param -Output: The generated output.
%
output_known_fact(Fact, Output) :-
  % Transform the fact into a sentence.
  phrase(sentence:sentence_body(Fact), Sentence),
  % Transform the sentence into a string.
  atomics_to_string(Sentence, ' ', Output).

%% output_proof(+Proof:atom, -Output:string)
%
% The output_proof/2 predicate transforms a proof step into a string output.
%
% @param +Proof: The proof step.
% @param -Output: The generated output.
%
output_proof(proof(_Clause, Fact), Output) :-
  engine:output_known_fact(Fact, Output).

% TODO: I don't know if this is used.
output_proof(proof(_Clause, Fact), Output):-
  engine:output_known_fact(Fact, FactOutput),
  % If the fact is not known, output a default response.
  atomic_list_concat([FactOutput, 'I do not know that is true.'], ' ', Output).

%% output_proof_list(+Question:atom, +ProofList:list, -Output:string)
%
% The output_proof_list/2 predicate transforms a question and a proof list into a string output.
%
% @param +Question: The question.
% @param +ProofList: The proof list.
% @param -Output: The generated output.
%
output_proof_list((Head :- Body | Certainty), ProofList, Output) :-
  % Transform each step of the proof into a sentence.
  maplist(engine:output_proof, ProofList, OutputListProof),
  % Transform the question into a clause.
  phrase(sentence:sentence_body([(Head :- Body | Certainty)]), Clause),
  % Transform the clause into a sentence.
  atomic_list_concat([therefore|Clause], ' ', Sentence),
  % Append the sentence to the output.
  append(OutputListProof, [Sentence], OutputList),
  % Transform the sentences into strings.
  atomic_list_concat(OutputList, ', ', Output).


output_proof_list((Question | Certainty), ProofList, Output) :-
  % Transform each step of the proof into a sentence.
  maplist(engine:output_proof, ProofList, OutputListProof),
  % Transform the question into a clause.
  phrase(sentence:sentence_body([(Question :- true | Certainty)]), Clause),
  % Transform the clause into a sentence.
  atomic_list_concat([therefore|Clause], ' ', Sentence),
  % Append the sentence to the output.
  append(OutputListProof, [Sentence], OutputList),
  % Transform the sentences into strings.
  atomic_list_concat(OutputList, ', ', Output).