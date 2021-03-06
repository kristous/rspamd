# Writing rspamd rules

In this tutorial, I describe how to create new rules for rspamd both lua and regexp ones.

## Introduction

Rules are the essential part of spam filtering system and rspamd ships with some prepared rules. However, if you run your
own system you might want to have your own rules for better spam filtering or better false positives rate. Rules are usually
written in `lua` language, where you specify both custom logic and generic regular expressions.

## Configuration files

Since rspamd is shipped with internal rules it is a good idea to store your custom rules and configuration in some separate file
to avoid clash with the pre-built rules that might change from version to version. There are some possibilities for these purposes:

- Local rules in lua should be stored in the file named `${CONFDIR}/lua/rspamd.local.lua` where `${CONFDIR}` is the directory where your configuration files are placed (e.g. `/etc/rspamd` or `/usr/local/etc/rspamd` for some systems)
- Local configuration that **adds** options to rspamd should be placed in `${CONFDIR}/rspamd.conf.local`
- Local configuration that **overrides** the default settings should be placed in `${CONFDIR}/rspamd.conf.override`

Lua local configuration can be used for both override and extending:

rspamd.lua:

~~~lua
config['regexp']['symbol'] = '/some_re/'
~~~

rspamd.local.lua:

~~~lua
config['regexp']['symbol1'] = '/other_re/' -- add 'symbol1' key to the table
config['regexp']['symbol'] = '/override_re/' -- replace regexp for 'symbol'
~~~

For the configuration rules you can take a look at the following examples:

rspamd.conf:

~~~nginx
var1 = "value1";

section "name" {
	var2 = "value2";
}
~~~

rspamd.conf.local:

~~~nginx
var1 = "value2";

section "name" {
	var3 = "value3";
}
~~~

Resulting config:

~~~nginx
var1 = "value1";
var1 = "value2";

section "name" {
	var2 = "value2";
}
section "name" {
	var3 = "value3";
}
~~~

Override example:

rspamd.conf:

~~~nginx
var1 = "value1";

section "name" {
	var2 = "value2";
}
~~~

rspamd.conf.override:

~~~nginx
var1 = "value2";

section "name" {
	var3 = "value3";
}
~~~

Resulting config:

~~~nginx
var1 = "value2";

# Note that var2 is removed completely
section "name" {
	var3 = "value3";
}
~~~

The conjunction of `override` and `local` configs should allow to resolve complicated issues without having a Turing complete language to distinguish cases.

## Writing rules

There are two main types of rules that are normally defined by rspamd:

- `Lua` rules: pieces of code in lua programming language to work with messages processed
- `Regexp` rules: regular expressions and combinations of regular expressions to match specific patterns

Lua rules are useful to do some complex tasks: ask DNS, query redis or HTTP, examine some task specific details. Regexp rules are useful since they are
optimized by rspamd heavily (especially when `hyperscan` is enabled) and allow to match custom patterns in headers, urls, text parts and even the whole message body.

### Rules weights

Rules weights are usually defined in the `metrics` which contain the following data:

- score triggers for different actions
- symbols scores
- symbols descriptions
- symbol group definitions:
	+ symbols in group
	+ description of groups
	+ joint group score limit

For built-in rules scores are placed in the file called `${CONFDIR}/metrics.conf`, however, you have two possibilities to define scores for your rules:

1. Define scores in `rspamd.conf.local` as following:

~~~nginx
metric "default" {
	symbol "MY_SYMBOL" {
		description = "my cool rule";
		score = 1.5;
	}
}
~~~

2. Define scores directly in lua when describing symbol:

~~~lua
-- regexp rule
config['regexp']['MY_SYMBOL'] = {
	re = '/a/M & From=/blah/',
	score = 1.5,
	description = 'my cool rule',
	group = 'my symbols'
}

-- lua rule
rspamd_config.MY_LUA_SYMBOL = {
	callback = function(task)
		-- Do something
		return true
	end,
	score = -1.5,
	description = 'another cool rule',
	group = 'my symbols'
}
~~~

## Regexp rules

Regexp rules are executed by `regexp` module of rspamd and you can find the detailed description of regexp syntax in [the module documentation](../modules/regexp.md)
In this tutorial, I will give merely some performance considerations about regular expressions:

* Prefer lightweight regexps, such as header or url regexps to heavy ones, such as mime or body regexps
* If you need to match some text in the message's content, prefer `mime` regexp as they are executed on text content only
* If you **really** need to match the whole messages, then you might also consider [trie](../modules/trie.md) module as it is significantly faster
* Avoid complex regexps, avoid backtracing, avoid negative groups `(?!)`, avoid capturing patterns (replace with `(?:)`), avoid potentially empty patterns, e.g. `/^.*$/`

Following these rules allows to create fast but still efficient rules. To add regexp rules you should use `config` global table that is defined in any lua file used by rspamd:

~~~lua
config['regexp'] = {} -- Remove all regexp rules (including internal ones)
local reconf = config['regexp'] -- Create alias for regexp configs

local re1 = 'From=/foo@/H' -- Mind local here
local re2 = '/blah/P'

reconf['SYMBOL'] = {
	re = string.format('(%s) && !(%s)', re1, re2), -- use string.format to create expression
	score = 1.2,
	description = 'some description',

	condition = function(task) -- run this rule only if some condition is satisfied
		return true
	end,
}
~~~

## Lua rules

Lua rules are more powerful than regexp ones but they are not optimized so heavily and can cause performance issues if written incorrectly. All lua rules
accept a special parameter called `task` which represents a message scanned.

### Return values

Each lua rule can return 0 or false meaning that the rule has not matched or true if the symbol should be inserted.
In fact, you can return any positive or negative number which would be multiplied by rule's score, e.g. if rule score is
`1.2`, then when your function returns `1` then symbol will have score `1.2`, and when your function returns `2.0` then the symbol will have score `2.4`.

### Rules conditions

Like regexp rules, conditions are allowed for lua regexps, for example:

~~~lua
rspamd_config.SYMBOL = {
	callback = function(task)
		return 1
	end,
	score = 1.2,
	description = 'some description',

	condition = function(task) -- run this rule only if some condition is satisfied
		return true
	end,
}
~~~

### Useful task manipulations

There are a number of methods in [task](../lua/task.md) objects. For example, you can get any parts in a message:

~~~lua
rspamd_config.HTML_MESSAGE = {
  callback = function(task)
    local parts = task:get_text_parts()

    if parts then
      for i,p in ipairs(parts) do
        if p:is_html() then
          return 1
        end
      end
    end

    return 0
  end,
  score = -0.1,
  description = 'HTML included in message',
}
~~~

You can get HTML information:

~~~lua
local function check_html_image(task, min, max)
  local tp = task:get_text_parts()

  for _,p in ipairs(tp) do
    if p:is_html() then
      local hc = p:get_html()
      local len = p:get_length()


      if len >= min and len < max then
        local images = hc:get_images()
        if images then
          for _,i in ipairs(images) do
            if i['embedded'] then
              return true
            end
          end
        end
      end
    end
  end
end

rspamd_config.HTML_SHORT_LINK_IMG_1 = {
  callback = function(task)
    return check_html_image(task, 0, 1024)
  end,
  score = 3.0,
  group = 'html',
  description = 'Short html part (0..1K) with a link to an image'
}
~~~

You can get message headers with full information passed:

~~~lua

rspamd_config.SUBJ_ALL_CAPS = {
  callback = function(task)
    local util = require "rspamd_util"
    local sbj = task:get_header('Subject')

    if sbj then
      local stripped_subject = subject_re:search(sbj, false, true)
      if stripped_subject and stripped_subject[1] and stripped_subject[1][2] then
        sbj = stripped_subject[1][2]
      end

      if util.is_uppercase(sbj) then
        return true
      end
    end

    return false
  end,
  score = 3.0,
  group = 'headers',
  description = 'All capital letters in subject'
}
~~~

You can also access HTTP headers, urls and other useful properties of rspamd tasks. Moreover, you can use
global convenience modules exported by rspamd, such as [rspamd_util](../lua/util.md) or [rspamd_logger](../lua/logger.md) by requiring them in your rules:

~~~lua
rspamd_config.SUBJ_ALL_CAPS = {
  callback = function(task)
    local util = require "rspamd_util"
    local logger = require "rspamd_logger"
    ...
  end,
}
~~~

## Rspamd symbols

Rspamd rules are represented as three major categories:

1. Pre-filters - run before other rules
2. Filters - run normally
3. Post-filters - run after all checks

The most common type of rules is generic filters. Each filter is basically a callback that is
executed by rspamd at some time and optional symbol name associated with this callback. In general, there
are three possibilities to register symbols:

* register callback and associated symbol
* register just a plain callback
* register symbol with no own callback (*virtual* symbol)

The last option is useful when you have a single callback but with different results possible, for example
`SYMBOL_ALLOW` and `SYMBOL_DENY` which have the opposite meaning. Filters are registered with three methods:

* `rspamd_config:register_symbol('SYMBOL', nominal_weight, callback)` - registers normal symbol
* `rspamd_config:register_callback_symbol(nominal_weight, callback)` - registers callback only symbol
* `rspamd_config:register_virtual_symbol('SYMBOL', nominal_weight, id)` - registers normal symbol

`nominal_weight` is used to define priority and the initial score multiplier. It should be usually `1.0` for normal symbols and `-1.0` for symbols with negative scores that should be executed before other symbols. Here is an example of registering one callback and a couple of virtual symbols used in [dmarc](../modules/dmarc.md) module:

~~~lua
local id = rspamd_config:register_callback_symbol('DMARC_CALLBACK', 1.0,
  dmarc_callback)
rspamd_config:register_virtual_symbol('DMARC_POLICY_ALLOW', -1, id)
rspamd_config:register_virtual_symbol('DMARC_POLICY_REJECT', 1, id)
rspamd_config:register_virtual_symbol('DMARC_POLICY_QUARANTINE', 1, id)
rspamd_config:register_virtual_symbol('DMARC_POLICY_SOFTFAIL', 1, id)
rspamd_config:register_dependency(id, symbols['spf_allow_symbol'])
rspamd_config:register_dependency(id, symbols['dkim_allow_symbol'])
~~~

Numeric `id` is returned by registration functions with callbacks (`register_symbol` or `register_callback_symbol`) and can be used to link symbols:

* add virtual symbols associated with this callback;
* correctly display average time for symbols without callbacks;
* properly sort symbols;
* register dependencies on virtual symbols (in fact, the true dependency is created based on the parent symbol but it is sometimes convenient to use virtual symbols for simplicity)

### Asynchronous actions

For asynchronous actions, such as redis access or DNS checks it is recommended to use
dedicated callbacks, called symbol handlers. The difference to generic lua rules is that
dedicated callbacks are not obliged to return value but they use method `task:insert_result(symbol, weight)` to
indicate match. All lua plugins are implemented as symbol handlers. Here is a simple example of symbol handler that checks DNS:

~~~lua
rspamd_config:register_symbol('SOME_SYMBOL', 1.0,
	function(task)
		local to_resolve = 'google.com'
		local logger = require "rspamd_logger"

		local dns_cb = function(resolver, to_resolve, results, err)
			if results then
				logger.infox(task, '<%1> host: [%2] resolved for symbol: %3',
					task:get_message_id(), to_resolve, 'RULE')
				task:insert_result(rule['symbol'], 1)
			end
		end
		task:get_resolver():resolve_a({
			task=task,
			name = to_resolve,
			callback = dns_cb})
	end)
~~~

You can also set the desired score and description if you'd like:

~~~lua
rspamd_config:set_metric_symbol('SOME_SYMBOL', 1.2, 'some description')
-- Table version
if rule['score'] then
  if not rule['group'] then
    rule['group'] = 'whitelist'
  end
  rule['name'] = symbol
  rspamd_config:set_metric_symbol(rule)
end
~~~

## Difference between `config` and `rspamd_config`

It might be confusing that there are two variables with a common meaning. That comes from
the history of rspamd and was used previously for a purpose. However, currently `rspamd_config` represents
the object that can do many things:

* Get configuration options:

~~~lua
rspamd_config:get_all_opts('section')
~~~

* Add maps:

~~~lua
rule['map'] = rspamd_config:add_kv_map(rule['domains'],
            "Whitelist map for " .. symbol)
~~~

* Register callbacks for symbols:

~~~lua
rspamd_config:register_symbol('SOME_SYMBOL', 1.0, some_functions)
~~~

* Register lua rules (note that `__newindex` metamethod is actually used here):

~~~lua
rspamd_config.SYMBOL = {...}
~~~

* Register composites, prefilters, postfilters and so on

On the contrary, `config` global is extremely simple: it's just a plain table of configuration options that is exactly the same
as defined in `rspamd.conf` (and `rspamd.conf.local` or `rspamd.conf.override`). However, you can also use lua tables and even functions for some
options. For example, `regexp` module also can accept `callback` argument:

~~~lua
config['regexp']['SYMBOL'] = {
  callback = function(task) ... end,
  ...
}
~~~

However, such a syntax is discouraged and is preserved mostly for compatibility reasons.

## Configuration applying order

It might be unclear, but there is a strict order of configuration options application and replacements:

1. `rspamd.conf` and `rspamd.conf.local` are processed
2. `rspamd.conf.override` is processed and it **overrides** anything parsed on the previous step
3. **Lua** rules are loaded and they can override everything from the previous steps, with the important exception of rules scores, that are **NOT** overriden if the according symbol is also defined in some `metric` section
4. **Dynamic** configuration defined by webui (normally) is loaded and it can override rules scores or action scores from the previous steps

## Rules check order

Rules in rspamd are checked in the following order:

1. **Prefilters**: checked every time and can stop all further processing by calling `task:set_pre_result()`
2. **All symbols***: can depend on each other by calling `rspamd_config:add_dependency(from, to)`
3. **Statistics**: is checked only when all symbols are checked
4. **Composites**: combine symbols to adjust the final results
5. **Post filters**: are executed even if a message is already rejected and symbols processing has been stopped
