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
	case do_validate(Data, Pattern, [root]) of
		{true, _, _, _, _} ->
			true;
		{false, MissmatchData, MissmatchPattern, Error, Path} ->
			throw({error, {invalid_data, {MissmatchData, MissmatchPattern, Error, lists:reverse(Path)}}})
	end.

%% @doc Validate data against a pattern. Returns true if matching, returns false if not.
%% @end
-spec validate(Data::term(), Pattern::term()) -> true | false.
validate(Data, Pattern) ->
	case do_validate(Data, Pattern, [root]) of
		{true, _, _, _, _} ->
			true;
		{false, _, _, _, _} ->
			false
	end.


-spec do_validate(Data::term(), Pattern::term(), Path::list()) -> {true|false, term(), term(), term(), list()}.
do_validate(Data, {'_'}, Path) -> {true, Data, undefined, undefined, Path};
do_validate(String, {string}, Path) ->
	case is_string(String) of
		true ->  {true, String, undefined, undefined, Path};
		false -> {false, String, {string}, not_a_string, Path}
	end;
do_validate(Integer, {integer}, Path) ->
	case is_integer(Integer) of
		true ->  {true,  Integer, undefined, undefined, Path};
		false -> {false, Integer, {integer}, not_an_integer, Path}
	end;
do_validate(Float, {float}, Path) ->
	case is_float(Float) of
		true ->  {true, Float, undefined, undefined, Path};
		false -> {false, Float, {integer}, not_a_float, Path}
	end;
do_validate(Number, {numeric}, Path) ->
	case is_integer(Number) orelse is_float(Number) of
		true ->  {true,  Number, undefined, undefined, Path};
		false -> {false, Number, {numeric}, not_numeric, Path}
	end;
do_validate(Atom, {atom}, Path) ->
	case is_atom(Atom) of
		true ->  {true, Atom, undefined, undefined, Path};
		false -> {false, Atom, {atom}, not_an_atom, Path}
	end;
do_validate(Binary, {binary}, Path) ->
	case is_binary(Binary) of
		true ->  {true, Binary, undefined, undefined, Path};
		false -> {false, Binary, {binary}, not_a_binary, Path}
	end;
do_validate(Date, {datetime}, Path) ->
	case is_ISO_8601_without_seconds(Date) of
		true ->  {true, Date, undefined, undefined, Path};
		false -> {false, Date, {binary}, not_a_datetime, Path}
	end;
do_validate([], {list, []}, Path) ->  {true, [], undefined, undefined, Path};
do_validate(List, {list, ['_']}, Path) ->
	case is_list(List) of
		true ->  {true,  List, undefined, undefined, Path};
		false -> {false, List, {list, ['_']}, not_a_list, Path}
	end;
do_validate(List, Pattern = {list, ['*', {Type}]}, Path) ->
	case is_list(List) of
		true ->
			case lists:filter(fun(E) -> {Valid, _, _, _, _} = do_validate(E, {Type}, [list_element|Path]), Valid =:= false end, List) of
				[] ->
					{true, List, undefined, undefined, Path};
				[FaultyData|_] ->
					do_validate(FaultyData, {Type}, [list_element|Path])
			end;
		false ->
			{false, List, Pattern, not_a_list, Path}
	end;

do_validate(List, {list, ['*' | [Pattern]]}, Path) when is_list(List) ->
	case lists:filter(fun(E) -> {Valid, _, _, _, _} = do_validate(E, Pattern, [list_element|Path]), Valid =:= false end, List) of
		[] ->
			{true, List, undefined, undefined, Path};
		[FaultyData|_] ->
			do_validate(FaultyData, Pattern, [list_element|Path])
	end;

do_validate(List, {list, PatternList}, Path) when (is_list(List) and is_list(PatternList)) ->
		case length(List) =:= length(PatternList) of
			true ->
				case lists:filter(fun({E, Pat}) -> {Valid, _, _, _, _} = do_validate(E, Pat, [list_element|Path]), Valid =:= false end, lists:zip(List, PatternList)) of
					[{FaultyData, Pattern}|_] ->
						do_validate(FaultyData, Pattern, [list_element|Path]);
					[] ->
						{true, List, undefined, undefined, Path}
				end;
			false ->
				{false, List, PatternList, wrong_length, Path}
		end;

do_validate(Dict, {dict, []}, Path) ->
	case is_dict(Dict) of
		true ->
			case dict:size(Dict) =:= 0 of
				true ->  {true,  Dict, undefined, undefined, Path};
				false -> {false, Dict, {dict, []}, non_empty_dict, Path}
			end;
		false ->
			{false, Dict, {dict, []}, not_a_dict, Path}
	end;

	
do_validate(Dict, {dict, ['_']}, Path) ->
	case is_dict(Dict) of
		true ->
			{true,  Dict, undefined, undefined, Path};
		false ->
			{false, Dict, {dict, []}, not_a_dict, Path}
	end;


do_validate(Dict, {dict, ['_' | PatternList]}, Path) ->
	case is_dict(Dict) of
		true ->
			do_validate(Dict, {dict, PatternList}, true, Path);
		false ->
			{false, Dict, {dict, []}, not_a_dict, Path}
	end;


do_validate(Dict, {dict, PatternList}, Path) ->
	case is_dict(Dict) of
		true ->
			do_validate(Dict, {dict, PatternList}, false, Path);
		false ->
			{false, Dict, {dict, []}, not_a_dict, Path}
	end;

do_validate(Data, {exact, Pattern}, Path) ->
	case Data =:= Pattern of
		true ->
			{true,  Data, undefined, undefined, Path};
		false ->
			{false, Data, {exact, Pattern}, does_not_equal, Path}
	end;
		

do_validate(Data, {satisfies, Fun}, Path) when is_function(Fun) ->
	case Fun(Data) of
		true ->  {true,  Data, undefined, undefined, Path};
		false -> {false, Data, {satisfies, Fun}, does_not_satisfy_fun, Path}
	end;

do_validate(Data, {satisfies, {Function}}, Path) ->
	do_validate(Data, {satisfies, {erlang, Function}}, Path);

do_validate(Data, {satisfies, {Module, Function}}, Path) ->
	case apply(Module, Function, [Data]) of
		true ->  {true,  Data, undefined, undefined, Path};
		false -> {false, Data, {satisfies, {Module, Function}}, does_not_satisfy_fun, Path}
	end;

do_validate(Data, {oneof, Patterns}, Path) ->
	case lists:filter(fun(Pattern) -> {Valid, _, _, _, _} = do_validate(Data, Pattern, Path), Valid =:= true end, Patterns) of
		[] ->
			{false, Data, {oneof, Patterns}, no_match, Path};
		_ ->
			{true, Data, undefined, undefined, Path}
	end;

do_validate(Data, Pattern, Path) ->
			{false, Data, Pattern, invalid_pattern, Path}.

do_validate(Dict, {dict, PatternList}, TolerateAdditional, Path) ->
	case is_dict(Dict) of
		false -> 
			{false, Dict, {dict, PatternList}, not_a_dict, Path};
		true ->
			case is_list(PatternList) of
			false ->
				{false, Dict, {dict, PatternList}, pattern_not_a_list, Path};
			true ->
				case (TolerateAdditional =:= true) or (length(PatternList) =:= dict:size(Dict)) of
					false ->
						{false, Dict, {dict, PatternList}, invalid_length, Path};
					true ->
						case lists:filter(
							fun({Key, Pat}) ->
								{Valid, _, _, _, _} = 
								try
									do_validate(dict:fetch(Key, Dict), Pat, [Key|Path])
								catch
									error:badarg -> {false, undefined, undefined, undefined, undefined}
								end,
								Valid =:= false end, PatternList) of
							[] ->
								{true, Dict, undefined, undefined, Path};
							[{Key, Pat}] ->
								try
									do_validate(dict:fetch(Key, Dict), Pat, [Key|Path])
								catch
									error:badarg -> {false, Dict, Pat, key_does_not_exist, [Key|Path]}
								end
						end
				end
			end	
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

	invalide_pattern_test() ->
		?assertEqual(false, validate(something, {bogus_pattern})).
		
	is_string_test() ->
		?assertEqual(true, is_string("hello!")),
		?assertEqual(false, is_string([1000])),
		?assertEqual(false, is_string(somethingelse)).
	
	identity_test() ->
		?assertEqual(true, validate("same", {exact, "same"})),
		?assertEqual(false, validate("same", {exact, "other"})).

	fun_test() ->
		?assertEqual(true, validate("something", {satisfies, fun(E) -> is_list(E) end})),
		?assertEqual(false, validate(something, {satisfies, fun(E) -> is_list(E) end})),
		?assertEqual(true, validate("something", {satisfies, {is_list}})),
		?assertEqual(false, validate(something, {satisfies, {is_list}})),
		?assertEqual(true, validate("something", {satisfies, {erlang, is_list}})),
		?assertEqual(false, validate(something, {satisfies, {erlang, is_list}})).

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
  	?assertEqual(true, validate([1, "hi!", last], {list, [{exact, 1}, {string}, {atom}]})),
  	?assertEqual(false, validate([1, "hi!", last], {list, [{exact, 2}, {string}, {atom}]})),
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

	oneof_test() ->
		?assertEqual(true, validate(atom, {oneof, [{atom}, {integer}]})),
		?assertEqual(false, validate(<<"atom">>, {oneof, [{atom}, {integer}]})).		

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