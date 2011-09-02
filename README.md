# Debutten

Debutten (German for "good" or "well formed") is a simple data validator.<br/>

Installing
=========

Building
--------

get and install rebar: https://github.com/basho/rebar

        $ git clone git://github.com/odo/debutten.git
        $ cd debutten
        $ rebar compile

Usage (short version)
=========

        > debutten:validate(1, {integer}).   
        true
        > debutten:validate(one, {integer}).
        false
        > debutten:validate([one], {list, ['*', {atom}]}).
        true
        > debutten:validate([one, two], {list, ['*', {atom}]}).
        true
        > debutten:validate([one, "two"], {list, ['*', {atom}]}).
        false
        > debutten:validate([one, "two"], {list, [{atom}, {string}]}).
        true
        > debutten:validate([one, "two"], {list, [one, {string}]}).
        true
        > debutten:validate([two, "two"], {list, [one, {string}]}).
        false
        > debutten:validate([one, "two", three], {list, [{atom}, {string}]}).
        false


Usage (long version)
=========

Debutten compares terms against patterns.<br/>There are two types of patterns: Primitive and composite:

<b>Primitive types:</b>
<table border="1">
    <th>Pattern</th>
    <th>Matches</th>
    <tr>
      <td><code>{'_'}</code></td>
      <td>anything</td>
    </tr><tr>
      <td><code>{integer}</code></td>
      <td>An integer</td>
    </tr><tr>
      <td><code>{float}</code></td>
      <td>A float</td>
    </tr><tr>
      <td><code>{numeric}</code></td>
      <td>A float or an integer</td>
    </tr><tr>
      <td><code>{atom}</code></td>
      <td>An atom</td>
    </tr><tr>
      <td><code>{binary}</code></td>
      <td>A binary</td>
    </tr><tr>
    </tr><tr>
      <td><code>{string}</code></td>
      <td>A ASCII string (List of integers between 0 and 255)</td>
    </tr><tr>
      <td><code>{datetime}</code></td>
      <td>An ISO 8601 string without seconds, e.g. "2011-04-04T22:44"</td>
    </tr><tr>
      <td><code>{exact, Term}</code></td>
      <td>The exact term as compared with the =:= operator</td>
    </tr>
</table>

<b>Composite types:</b>
<table border="1">
    <th>Pattern</th>
    <th>Matches</th>
    <tr>
      <td><code>{list, ['_']}</code></td>
      <td>A list with arbitrary content</td>
    </tr><tr>
      <td><code>{list, []}</code></td>
      <td>An empty list</td>
    </tr><tr>
      <td><code>{list, ['*', {integer}]}</code></td>
      <td>A list with only integers</td>
    </tr><tr>
      <td><code>{list, [{integer}, {string}, {atom}]}</code></td>
      <td>An list with exactly one integer, string and one atom</td>
    </tr><tr>
      <td><code>{dict, []}</code></td>
      <td>A dictionary</td>
    </tr><tr>
    </tr><tr>
      <td><code>{dict, [{"key", {string}}, {"value", {integer}}</code></td>
      <td>A dictionary with two keys, "key" and "value" where "key" is a string and "value" us an integer.</td>
    </tr><tr>
    </tr><tr>
      <td><code>{dict, ['_', {"key", {string}}, {"value", {integer}}]}</code></td>
      <td>Same as above but with optional additional key value pairs.</td>
    </tr><tr>
      <td><code>{datetime}</code></td>
      <td>An ISO 8601 string without seconds, e.g. "2011-04-04T22:44"</td>
    </tr>
</table>

<b>Nesting:</b>
<table border="1">
    <th>Pattern</th>
    <th>Matches</th>
    <tr>
      <td><code>{dict, [
			'_',
			{"integer_array", {list, ['*', {integer}]}},
			{"string", {string}},
			{"some_array", {list, ['_']}},
			{"dict", {dict, [{this_must_be, {string}}]}}
			]}</code></td>
      <td>A dict with constrained types for its values</td>
    </tr>
</table>



