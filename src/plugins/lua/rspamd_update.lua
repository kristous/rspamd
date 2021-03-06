--[[
Copyright (c) 2016, Vsevolod Stakhov <vsevolod@highsecure.ru>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
]]--

-- This plugin implements dynamic updates for rspamd

local ucl = require "ucl"
require "fun" ()
local rspamd_logger = require "rspamd_logger"
local updates_priority = 2
local rspamd_config = rspamd_config
local hash = require "rspamd_cryptobox_hash"
local rspamd_version = rspamd_version

local function process_symbols(obj)
  each(function(sym, score)
    rspamd_config:set_metric_symbol({
      name = sym,
      score = score,
      priority = updates_priority
    })
  end, obj)
end
local function process_actions(obj)
  each(function(act, score)
    rspamd_config:set_metric_action({
      name = act,
      score = score,
      priority = updates_priority
    })
  end, obj)
end

local function process_actions(obj)
  each(function(key, code)
    dostring(code)
  end, obj)
end

local function check_version(obj)
  local ret = true

  if obj['min_version'] then
    if rspamd_version('cmp', obj['min_version']) < 0 then
      ret = false
      rspamd_logger.errx(rspamd_config, 'updates require at least %s version of rspamd',
        obj['min_version'])
    end
  end
  if obj['max_version'] then
    if rspamd_version('cmp', obj['max_version']) > 0 then
      ret = false
      rspamd_logger.errx(rspamd_config, 'updates require maximum %s version of rspamd',
        obj['max_version'])
    end
  end

  return ret
end

local function process_updates(data)
  local ucl = require "ucl"
  local parser = ucl.parser()
  local res,err = parser:parse_string(data)

  if not res then
    rspamd_logger.warnx(rspamd_config, 'cannot parse updates map: ' .. err)
  else
    local h = hash.create()
    h:update(data)
    local obj = parser:get_object()

    if check_version(obj) then
      if obj['symbols'] then
        process_symbols(obj['symbols'])
      end
      if obj['actions'] then
        process_actions(obj['actions'])
      end
      if obj['rules'] then
        process_rules(obj['rules'])
      end

      rspamd_logger.infox(rspamd_config, 'loaded new rules with hash "%s"',
        h:hex())
    end
  end

  return res
end

-- Configuration part
local section = rspamd_config:get_all_opt("rspamd_update")
if section then
  each(function(k, elt)
    if k == 'priority' then
      updates_priority = tonumber(elt)
    else
      if not rspamd_config:add_map(elt, "rspamd updates map", process_updates) then
        rspamd_logger.errx(rspamd_config, 'cannot load settings from %1', elt)
      end
    end
  end, section)
end
