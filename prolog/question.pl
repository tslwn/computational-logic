%% question: Question parser.
%
% This module parses questions and converts them into clauses.
%
:- module(question, [question/3]).

% --- Imports ---

:- use_module(grammar).

% --- Question parser ---

%% question(Question:list)//
%
% Parses a list of atoms into the head and body of a question.
%
% @param Question The list of atoms.
%
question(Question) -->
  question_word,
  question_body(Question).

question_word --> [].

%% question_body(Question:list)//
%
% Parses the body of a question.
%
% @param Question The list of atoms.
%
% "Who VerbPhrase?" questions.
question_body(Question) -->
  [who],
  grammar:verb_phrase(singular, _ => Question).

% "Is ProperNoun Property?" questions.
question_body(Question) -->
  [is],
  grammar:proper_noun(Noun, X),
  grammar:property(Noun, X => Question).

% "Does ProperNoun VerbPhrase?" questions.
question_body(Question) -->
  [does],
  grammar:proper_noun(_, X),
  grammar:verb_phrase(_, X => Question).
