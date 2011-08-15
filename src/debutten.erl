%% @author Florian Odronitz <odo@mac.com>
%% @copyright 2011 Florian Odronitz.
%%
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without restriction,
%% including without limitation the rights to use, copy, modify, merge,
%% publish, distribute, sublicense, and/or sell copies of the Software,
%% and to permit persons to whom the Software is furnished to do
%% so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included
%% in all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
%% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
%% IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
%% CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
%% TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
%% SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

%% @doc Debutten is a simple data validator.
%% @end

-module (debutten).
-export ([validate/2, validate_or_throw/2]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

%% @doc Validate data against a pattern. Returns true if matching, throws an exception if not.
%% @end
%% @spec validate_or_throw(Data::term(), Pattern::term()) -> true | false
%% @throws {invalid_data, {Pattern::term(), Data::term()}}
validate_or_throw(Data, Pattern) ->
	case ?MODULE:validate(Data, Pattern) of
		true ->
			true;
		false ->
			throw({invalid_data, {Data, Pattern}})
	end.

%% @doc Validate data against a pattern. Returns true if matching, returns false if not.
%% @end
%% @spec validate(Data::term(), Pattern::term()) -> true | false
validate(_, {'_'}) -> 						true;
validate(String, {string}) -> 		is_string(String);
validate(Integer, {integer}) -> 	is_integer(Integer);
validate(Float, {float}) -> 			is_float(Float);
validate(Number, {numeric}) -> 		is_integer(Number) orelse is_float(Number);
validate(Atom, {atom}) -> 				is_atom(Atom);
validate(Binary, {binary}) -> 			is_binary(Binary);
validate(Date, {datetime}) -> is_ISO_8601_without_seconds(Date);
validate([], {list, []}) -> 			true;
validate(List, {list, ['_']}) -> 	is_list(List);
validate(List, {list, ['*', {Type}]}) ->
	is_list(List) andalso lists:all(fun(E) -> validate(E, {Type}) end, List);

validate(List, {list, ['*' | [Pattern]]}) when is_list(List) ->
		lists:all(fun(R) -> R =:= true end, [validate(E, Pattern) || E <- List]);

validate(List, {list, Pattern_list}) when (is_list(List) and is_list(Pattern_list)) ->
		length(List) =:= length(Pattern_list) andalso
		lists:all(fun(R) -> R =:= true end, [validate(E, Pat) || {E, Pat} <- lists:zip(List, Pattern_list)]);

validate(Dict, {dict, []}) ->
	is_dict(Dict) andalso dict:size(Dict) =:= 0;
	
validate(Dict, {dict, ['_']}) -> is_dict(Dict);

validate(Dict, {dict, ['_' | PatternList]}) -> validate(Dict, {dict, PatternList}, true);

validate(Dict, {dict, PatternList}) -> validate(Dict, {dict, PatternList}, false);

validate(Data, Pattern) -> 
	throw({illegal_pattern, Pattern, Data}).

validate(Dict, {dict, PatternList}, Tolerate_additional) ->
	case is_dict(Dict) and is_list(PatternList) and ((Tolerate_additional =:= true) or (length(PatternList) =:= dict:size(Dict))) of
		true ->
			try
				lists:all(fun(R) -> R =:= true end, [validate(dict:fetch(Key, Dict), Pat) || {Key, Pat} <- PatternList])
			catch
				error:badarg -> false
			end;
		false ->
			false
	end.

is_ISO_8601_without_seconds(Date) ->
	case re:run(Date, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}$") of
		nomatch -> false;
		_				-> true
	end.
	
is_dict(D) -> is_tuple(D) andalso element(1, D) =:= dict.

is_char(Char) when Char < 0 -> false;
is_char(Char) when Char > 255 -> false;
is_char(_) -> true.

is_string(String) ->
	case is_list(String) of
		false -> false;
		true -> lists:all(fun(Char) -> is_char(Char) end, String)
	end.


%% ===================================================================
%% Unit Tests
%% ===================================================================
-ifdef(TEST).

	is_string_test() ->
		?assertEqual(true, is_string("hello!")),
		?assertEqual(false, is_string([1000])),
		?assertEqual(false, is_string(somethingelse)).

	widcard_test() ->
  	?assertEqual(true, validate("text", {'_'})),
  	?assertEqual(true, validate(1.3, {'_'})),
  	?assertEqual(true, validate(dict:new(), {'_'})).

	string_test() ->
  	?assertEqual(true, validate("text", {string})),
  	?assertEqual(false, validate(1.3, {string})).

	integer_test() ->
  	?assertEqual(true, validate(1, {integer})),
  	?assertEqual(false, validate("text", {integer})).

	float_test() ->
  	?assertEqual(true, validate(1.3, {float})),
  	?assertEqual(false, validate(1, {float})).

	numeric_test() ->
  	?assertEqual(true, validate(1.3, {numeric})),
  	?assertEqual(true, validate(1, {numeric})),
  	?assertEqual(false, validate(twelve, {numeric})).

	binary_test() ->
  	?assertEqual(true, validate(<<"1.3">>, {binary})),
  	?assertEqual(false, validate(1.3, {binary})).

	atom_test() ->
  	?assertEqual(true, validate(an_atom, {atom})),
  	?assertEqual(false, validate(3.2, {atom})).

	datetime_test() ->
  	?assertEqual(true, validate("2011-04-04T22:44", {datetime})),
  	?assertEqual(false, validate("20112-04-04T22/44", {datetime})),
  	?assertEqual(false, validate("20112-04-04X22:44", {datetime})),
  	?assertEqual(false, validate("20112-04-04X22:443", {datetime})),
  	?assertEqual(false, validate("20112-04-04T22:44", {datetime})).

	empty_list_test() ->
  	?assertEqual(true, validate([], {list, []})),
  	?assertEqual(false, validate([3.2], {list, []})).

	indifferent_list_test() ->
  	?assertEqual(true, validate([], {list, ['_']})),
  	?assertEqual(true, validate([3.2], {list, ['_']})).

	any_number_list_test() ->
  	?assertEqual(true, validate([1, 2, 3, 5], {list, ['*', {integer}]})),
  	?assertEqual(true, validate([], {list, ['*', {integer}]})),
  	?assertEqual(false, validate([1, "two", 3, 5], {list, ['*', {integer}]})),
  	?assertEqual(false, validate(random, {list, ['*', {integer}]})).

	any_number_nested_list_test() ->
		Pattern = {list, ['*',
			{list, 
				[{string}, {integer}]
			}]},
  	?assertEqual(true, validate([["1", 2], ["3", 5]], Pattern)),
  	?assertEqual(true, validate([], Pattern)),
  	?assertEqual(false, validate([["1", "2"], ["3", 5]], Pattern)).

	explicit_list_test() ->
  	?assertEqual(true, validate([1, "hi!", last], {list, [{integer}, {string}, {atom}]})).

	empty_dict_test() ->
		?assertEqual(true, validate(dict:new(), {dict, []})),
		?assertEqual(false, validate(dict:from_list([{some, "value"}]), {dict, []})),
		?assertEqual(false, validate(something_else, {dict, []})).
		
	indifferent_dict_test() ->
		?assertEqual(true, validate(dict:from_list([{some, "value"}]), {dict, ['_']})), 
		?assertEqual(false, validate([random], {dict, ['_']})). 

	explicit_dict_test() ->
		?assertEqual(true, validate(dict:from_list([{"key", "the_key"}, {"value", 7}]), {dict, [{"key", {string}}, {"value", {integer}}]})),
		?assertEqual(true, validate(dict:from_list([{"key", "the_key"}, {"value", 7}]), {dict, [{"key", {string}}, {"value", {integer}}]})),
		?assertEqual(false, validate(dict:from_list([{"key", "the_key"}, {"value", seven}]), {dict, [{"key", {string}}, {"value", {integer}}]})),
		?assertEqual(false, validate(dict:from_list([{"key", "the_key"}, {"value", 7}, {"illegal", 666}]), {dict, [{"key", {string}}, {"value", {string}}]})),
		?assertEqual(false, validate(dict:from_list([{"key", "the_key"}]), {dict, [{"key", {string}}, {"value", {string}}]})).

	explicit_dict_tolerate_additional_test() ->
		?assertEqual(true, validate(dict:from_list([{"key", "the_key"}, {"value", 7}]), {dict, ['_', {"key", {string}}, {"value", {integer}}]})),
		?assertEqual(true, validate(dict:from_list([{"key", "the_key"}, {"i can hide", 7}, {"value", 7}]), {dict, ['_', {"key", {string}}, {"value", {integer}}]})),
		?assertEqual(false, validate(dict:from_list([{"value", 7}]), {dict, ['_', {"key", {string}}, {"value", {integer}}]})),
		?assertEqual(false, validate(dict:from_list([{"key", "the_key"}, {"i can hide", 7}, {"value", no_allowed}]), {dict, ['_', {"key", {string}}, {"value", {integer}}]})).

	combination_test() ->
		Data = dict:from_list([
				{"some_array", [1, two]},
				{"integer_array", [1,2,3,4]},
				{"string", "string_val"},
				{"integer", 5},
				{"random", 12345},
				{"dict", dict:from_list([{this_must_be, "here"}])}
			]),
		Pattern = {dict, [
			'_',
			{"integer_array", {list, ['*', {integer}]}},
			{"string", {string}},
			{"some_array", {list, ['_']}},
			{"dict", {dict, [{this_must_be, {string}}]}}
			]},
		BadData1 = dict:from_list([
				{"some_array", [1, two]},
				{"integer_array", [1,2,3,4]},
				{"string", "string_val"},
				{"integer", 5},
				{"random", 12345},
				{"dict", dict:from_list([{this_must_be, "here"}, {the_cake, is_a_lie}])}
			]),
		BadPat1 = {dict, [
			{"integer_array", {list, ['*', {integer}]}},
			{"string", {string}},
			{"some_array", {list, ['_']}},
			{"dict", {dict, [{this_must_be, {string}}]}}
			]},
		?assertEqual(true, validate(Data, Pattern)),
		?assertEqual(false, validate(Data, BadPat1)),
		?assertEqual(false, validate(BadData1, Pattern)).

-endif.