-- Actually these regular expressions were obtained from SpamAssassin project, so they are licensed by apache license:
--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to you under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Definitions of header regexps

local reconf = config['regexp']
local rspamd_regexp = require "rspamd_regexp"

-- Subject needs encoding
-- Define encodings types
local subject_encoded_b64 = 'Subject=/=\\?\\S+\\?B\\?/iX'
local subject_encoded_qp = 'Subject=/=\\?\\S+\\?Q\\?/iX'
-- Define whether subject must be encoded (contains non-7bit characters)
local subject_needs_mime = 'Subject=/[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f-\\xff]/X'
-- Final rule
reconf['SUBJECT_NEEDS_ENCODING'] = string.format('!(%s) & !(%s) & (%s)', subject_encoded_b64, subject_encoded_qp, subject_needs_mime)

-- Detects that there is no space in From header (e.g. Some Name<some@host>)
reconf['R_NO_SPACE_IN_FROM'] = 'From=/\\S<[-\\w\\.]+\\@[-\\w\\.]+>/X'


rspamd_config.MISSING_SUBJECT = function(task)
  local hdr = task:get_header('Subject')

  if not hdr or #hdr == 0 then
    return true
  end

  return false
end

-- Detects bad content-transfer-encoding for text parts
-- For text parts (text/plain and text/html mainly)
local r_ctype_text = 'content_type_is_type(text)'
-- Content transfer encoding is 7bit
local r_cte_7bit = 'compare_transfer_encoding(7bit)'
-- And body contains 8bit characters
local r_body_8bit = '/[^\\x01-\\x7f]/Pr'
reconf['R_BAD_CTE_7BIT'] = string.format('(%s) & (%s) & (%s)', r_ctype_text, r_cte_7bit, r_body_8bit)

-- Detects missing To header
reconf['MISSING_TO']= '!raw_header_exists(To)';

-- Detects undisclosed recipients
local undisc_rcpt = 'To=/^<?undisclosed[- ]recipient/Hi'
reconf['R_UNDISC_RCPT'] = string.format('(%s)', undisc_rcpt)

-- Detects missing Message-Id
local has_mid = 'header_exists(Message-Id)'
reconf['MISSING_MID'] = '!header_exists(Message-Id)';

-- Received seems to be fake
reconf['R_RCVD_SPAMBOTS'] = 'Received=/^from \\[\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\] by [-.\\w+]{5,255}; [SMTWF][a-z][a-z], [\\s\\d]?\\d [JFMAJSOND][a-z][a-z] \\d{4} \\d{2}:\\d{2}:\\d{2} [-+]\\d{4}$/mH'

-- Charset is missing in message
reconf['R_MISSING_CHARSET']= string.format('content_type_is_type(text) & !content_type_has_param(charset) & !%s', r_cte_7bit);

-- Subject seems to be spam
reconf['R_SAJDING'] = 'Subject=/\\bsajding(?:om|a)?\\b/iH'

-- Find forged Outlook MUA
-- Yahoo groups messages
local yahoo_bulk = 'Received=/from \\[\\S+\\] by \\S+\\.(?:groups|scd|dcn)\\.yahoo\\.com with NNFMP/H'
-- Outlook MUA
local outlook_mua = 'X-Mailer=/^Microsoft Outlook\\b/H'
local any_outlook_mua = 'X-Mailer=/^Microsoft Outlook\\b/H'
reconf['FORGED_OUTLOOK_HTML'] = string.format('!%s & %s & %s', yahoo_bulk, outlook_mua, 'has_only_html_part()')

-- Recipients seems to be likely with each other (only works when recipients count is more than 5 recipients)
reconf['SUSPICIOUS_RECIPS'] = 'compare_recipients_distance(0.65)'

-- Recipients list seems to be sorted
reconf['SORTED_RECIPS'] = 'is_recipients_sorted()'

-- Spam string at the end of message to make statistics faults
reconf['TRACKER_ID'] = '/^[a-z0-9]{6,24}[-_a-z0-9]{2,36}[a-z0-9]{6,24}\\s*\\z/isPr'


-- From that contains encoded characters while base 64 is not needed as all symbols are 7bit
-- Regexp that checks that From header is encoded with base64 (search in raw headers)
local from_encoded_b64 = 'From=/\\=\\?\\S+\\?B\\?/iX'
-- From contains only 7bit characters (parsed headers are used)
local from_needs_mime = 'From=/[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f-\\xff]/Hr'
-- Final rule
reconf['FROM_EXCESS_BASE64'] = string.format('%s & !%s', from_encoded_b64, from_needs_mime)

-- From that contains encoded characters while quoted-printable is not needed as all symbols are 7bit
-- Regexp that checks that From header is encoded with quoted-printable (search in raw headers)
local from_encoded_qp = 'From=/\\=\\?\\S+\\?Q\\?/iX'
-- Final rule
reconf['FROM_EXCESS_QP'] = string.format('%s & !%s', from_encoded_qp, from_needs_mime)

-- To that contains encoded characters while base 64 is not needed as all symbols are 7bit
-- Regexp that checks that To header is encoded with base64 (search in raw headers)
local to_encoded_b64 = 'To=/\\=\\?\\S+\\?B\\?/iX'
-- To contains only 7bit characters (parsed headers are used)
local to_needs_mime = 'To=/[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f-\\xff]/Hr'
-- Final rule
reconf['TO_EXCESS_BASE64'] = string.format('%s & !%s', to_encoded_b64, to_needs_mime)

-- To that contains encoded characters while quoted-printable is not needed as all symbols are 7bit
-- Regexp that checks that To header is encoded with quoted-printable (search in raw headers)
local to_encoded_qp = 'To=/\\=\\?\\S+\\?Q\\?/iX'
-- Final rule
reconf['TO_EXCESS_QP'] = string.format('%s & !%s', to_encoded_qp, to_needs_mime)

-- Reply-To that contains encoded characters while base 64 is not needed as all symbols are 7bit
-- Regexp that checks that Reply-To header is encoded with base64 (search in raw headers)
local replyto_encoded_b64 = 'Reply-To=/\\=\\?\\S+\\?B\\?/iX'
-- Reply-To contains only 7bit characters (parsed headers are used)
local replyto_needs_mime = 'Reply-To=/[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f-\\xff]/Hr'
-- Final rule
reconf['REPLYTO_EXCESS_BASE64'] = string.format('%s & !%s', replyto_encoded_b64, replyto_needs_mime)

-- Reply-To that contains encoded characters while quoted-printable is not needed as all symbols are 7bit
-- Regexp that checks that Reply-To header is encoded with quoted-printable (search in raw headers)
local replyto_encoded_qp = 'Reply-To=/\\=\\?\\S+\\?Q\\?/iX'
-- Final rule
reconf['REPLYTO_EXCESS_QP'] = string.format('%s & !%s', replyto_encoded_qp, replyto_needs_mime)

-- Cc that contains encoded characters while base 64 is not needed as all symbols are 7bit
-- Regexp that checks that Cc header is encoded with base64 (search in raw headers)
local cc_encoded_b64 = 'Cc=/\\=\\?\\S+\\?B\\?/iX'
-- Co contains only 7bit characters (parsed headers are used)
local cc_needs_mime = 'Cc=/[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f-\\xff]/Hr'
-- Final rule
reconf['CC_EXCESS_BASE64'] = string.format('%s & !%s', cc_encoded_b64, cc_needs_mime)

-- Cc that contains encoded characters while quoted-printable is not needed as all symbols are 7bit
-- Regexp that checks that Cc header is encoded with quoted-printable (search in raw headers)
local cc_encoded_qp = 'Cc=/\\=\\?\\S+\\?Q\\?/iX'
-- Final rule
reconf['CC_EXCESS_QP'] = string.format('%s & !%s', cc_encoded_qp, cc_needs_mime)


-- Detect forged outlook headers
-- OE X-Mailer header
local oe_mua = 'X-Mailer=/\\bOutlook Express [456]\\./H'
-- OE Message ID format
local oe_msgid_1 = 'Message-Id=/^<?[A-Za-z0-9-]{7}[A-Za-z0-9]{20}\\@hotmail\\.com>?$/mH'
local oe_msgid_2 = 'Message-Id=/^<?(?:[0-9a-f]{8}|[0-9a-f]{12})\\$[0-9a-f]{8}\\$[0-9a-f]{8}\\@\\S+>?$/H'
-- EZLM remail of message
local lyris_ezml_remailer = 'List-Unsubscribe=/<mailto:(?:leave-\\S+|\\S+-unsubscribe)\\@\\S+>$/H'
-- Header of wacky sendmail
local wacky_sendmail_version = 'Received=/\\/CWT\\/DCE\\)/H'
-- Iplanet received header
local iplanet_messaging_server = 'Received=/iPlanet Messaging Server/H'
-- Hotmail message id
local hotmail_baydav_msgid = 'Message-Id=/^<?BAY\\d+-DAV\\d+[A-Z0-9]{25}\\@phx\\.gbl?>$/H'
-- Sympatico message id
local sympatico_msgid = 'Message-Id=/^<?BAYC\\d+-PASMTP\\d+[A-Z0-9]{25}\\@CEZ\\.ICE>?$/H'
-- Mailman message id
local mailman_msgid = 'Message-ID=/^<mailman\\.\\d+\\.\\d+\\.\\d+\\..+\\@\\S+>$/H'
-- Message id seems to be forged
local unusable_msgid = string.format('(%s | %s | %s | %s | %s | %s)',
					lyris_ezml_remailer, wacky_sendmail_version, iplanet_messaging_server, hotmail_baydav_msgid, sympatico_msgid, mailman_msgid)
-- Outlook express data seems to be forged
local forged_oe = string.format('(%s & !%s & !%s & !%s)', oe_mua, oe_msgid_1, oe_msgid_2, unusable_msgid)
-- Outlook specific headers
local outlook_dollars_mua = 'X-Mailer=/^Microsoft Outlook(?: 8| CWS, Build 9|, Build 10)\\./H'
local outlook_dollars_other = 'Message-Id=/^<?\\!\\~\\!>?/H'
local vista_msgid = 'Message-Id=/^<?[A-F\\d]{32}\\@\\S+>?$/H'
local ims_msgid = 'Message-Id=/^<?[A-F\\d]{36,40}\\@\\S+>?$/H'
-- Forged outlook headers
local forged_outlook_dollars = string.format('(%s & !%s & !%s & !%s & !%s & !%s)',
					outlook_dollars_mua, oe_msgid_2, outlook_dollars_other, vista_msgid, ims_msgid, unusable_msgid)
-- Outlook versions that should be excluded from summary rule
local fmo_excl_o3416 = 'X-Mailer=/^Microsoft Outlook, Build 10.0.3416$/H'
local fmo_excl_oe3790 = 'X-Mailer=/^Microsoft Outlook Express 6.00.3790.3959$/H'
-- Summary rule for forged outlook
reconf['FORGED_MUA_OUTLOOK'] = string.format('(%s | %s) & !%s & !%s & !%s',
					forged_oe, forged_outlook_dollars, fmo_excl_o3416, fmo_excl_oe3790, vista_msgid)

-- HTML outlook signs
local mime_html = 'content_type_is_type(text) & content_type_is_subtype(/.?html/)'
local tag_exists_html = 'has_html_tag(html)'
local tag_exists_head = 'has_html_tag(head)'
local tag_exists_meta = 'has_html_tag(meta)'
local tag_exists_body = 'has_html_tag(body)'
reconf['FORGED_OUTLOOK_TAGS'] = string.format('!%s & %s & %s & !(%s & %s & %s & %s)',
					yahoo_bulk, any_outlook_mua, mime_html, tag_exists_html, tag_exists_head,
					tag_exists_meta, tag_exists_body)

-- Forged OE/MSO boundary
reconf['SUSPICIOUS_BOUNDARY']	= 'Content-Type=/^\\s*multipart.+boundary="----=_NextPart_000_[A-Z\\d]{4}_(00EBFFA4|0102FFA4|32C6FFA4|3302FFA4)\\.[A-Z\\d]{8}"[\\r\\n]*$/siX'
-- Forged OE/MSO boundary
reconf['SUSPICIOUS_BOUNDARY2']	= 'Content-Type=/^\\s*multipart.+boundary="----=_NextPart_000_[A-Z\\d]{4}_(01C6527E)\\.[A-Z\\d]{8}"[\\r\\n]*$/siX'
-- Forged OE/MSO boundary
reconf['SUSPICIOUS_BOUNDARY3']	= 'Content-Type=/^\\s*multipart.+boundary="-----000-00\\d\\d-01C[\\dA-F]{5}-[\\dA-F]{8}"[\\r\\n]*$/siX'
-- Forged OE/MSO boundary
local suspicious_boundary_01C4	= 'Content-Type=/^\\s*multipart.+boundary="----=_NextPart_000_[A-Z\\d]{4}_01C4[\\dA-F]{4}\\.[A-Z\\d]{8}"[\\r\\n]*$/siX'
local suspicious_boundary_01C4_date	= 'Date=/^\\s*\\w\\w\\w,\\s+\\d+\\s+\\w\\w\\w 20(0[56789]|1\\d)/'
reconf['SUSPICIOUS_BOUNDARY4']	= string.format('(%s) & (%s)', suspicious_boundary_01C4, suspicious_boundary_01C4_date)

-- Detect forged The Bat! headers
-- The Bat! X-Mailer header
local thebat_mua_any = 'X-Mailer=/^\\s*The Bat!/H'
-- The Bat! common Message-ID template
local thebat_msgid_common = 'Message-ID=/^<?\\d+\\.\\d+\\@\\S+>?$/mH'
-- Correct The Bat! Message-ID template
local thebat_msgid = 'Message-ID=/^<?\\d+\\.(19[789]\\d|20\\d\\d)(0\\d|1[012])([012]\\d|3[01])([0-5]\\d)([0-5]\\d)([0-5]\\d)\\@\\S+>?/mH'
-- Summary rule for forged The Bat! Message-ID header
reconf['FORGED_MUA_THEBAT_MSGID'] = string.format('(%s) & !(%s) & (%s) & !(%s)', thebat_mua_any, thebat_msgid, thebat_msgid_common, unusable_msgid)
-- Summary rule for forged The Bat! Message-ID header with unknown template
reconf['FORGED_MUA_THEBAT_MSGID_UNKNOWN'] = string.format('(%s) & !(%s) & !(%s) & !(%s)', thebat_mua_any, thebat_msgid, thebat_msgid_common, unusable_msgid)


-- Detect forged KMail headers
-- KMail User-Agent header
local kmail_mua = 'User-Agent=/^\\s*KMail\\/1\\.\\d+\\.\\d+/H'
-- KMail common Message-ID template
local kmail_msgid_common = 'Message-Id=/^<?\\s*\\d+\\.\\d+\\.\\S+\\@\\S+>?$/mH'
function kmail_msgid (task)
	local regexp_text = '<(\\S+)>\\|(19[789]\\d|20\\d\\d)(0\\d|1[012])([012]\\d|3[01])([0-5]\\d)([0-5]\\d)\\.\\d+\\.\\1$'
	local re = rspamd_regexp.create_cached(regexp_text)
	local header_msgid = task:get_header('Message-Id')
	if header_msgid then
		local header_from = task:get_header('From')
		if header_from and re:match(header_from.."|"..header_msgid) then return true end
	end
	return false
end
-- Summary rule for forged KMail Message-ID header
reconf['FORGED_MUA_KMAIL_MSGID'] = string.format('(%s) & (%s) & !(%s) & !(%s)', kmail_mua, kmail_msgid_common, 'kmail_msgid', unusable_msgid)
-- Summary rule for forged KMail Message-ID header with unknown template
reconf['FORGED_MUA_KMAIL_MSGID_UNKNOWN'] = string.format('(%s) & !(%s) & !(%s)', kmail_mua, kmail_msgid_common, unusable_msgid)

-- Detect forged Opera Mail headers
-- Opera Mail User-Agent header
local opera1x_mua = 'User-Agent=/^\\s*Opera Mail\\/1[01]\\.\\d+ /H'
-- Opera Mail Message-ID template
local opera1x_msgid = 'Message-ID=/^<?op\\.[a-z\\d]{14}\\@\\S+>?$/H'
-- Suspicious Opera Mail User-Agent header
local suspicious_opera10w_mua = 'User-Agent=/^\\s*Opera Mail\\/10\\.\\d+ \\(Windows\\)$/H'
-- Suspicious Opera Mail Message-ID, apparently from KMail
local suspicious_opera10w_msgid = 'Message-Id=/^<?2009\\d{8}\\.\\d+\\.\\S+\\@\\S+?>$/H'
-- Summary rule for forged Opera Mail User-Agent header and Message-ID header from KMail
reconf['SUSPICIOUS_OPERA_10W_MSGID'] = string.format('(%s) & (%s)', suspicious_opera10w_mua, suspicious_opera10w_msgid)
-- Summary rule for forged Opera Mail Message-ID header
reconf['FORGED_MUA_OPERA_MSGID'] = string.format('(%s) & !(%s) & !(%s) & !(%s)', opera1x_mua, opera1x_msgid, reconf['SUSPICIOUS_OPERA_10W_MSGID'], unusable_msgid)


-- Detect forged Mozilla Mail/Thunderbird/Seamonkey headers
-- Mozilla based X-Mailer
local user_agent_mozilla5	= 'User-Agent=/^\\s*Mozilla\\/5\\.0/H'
local user_agent_thunderbird	= 'User-Agent=/^\\s*(Thunderbird|Mozilla Thunderbird|Mozilla\\/.*Gecko\\/.*Thunderbird\\/)/H'
local user_agent_seamonkey	= 'User-Agent=/^\\s*Mozilla\\/5\\.0\\s.+\\sSeaMonkey\\/\\d+\\.\\d+/H'
local user_agent_mozilla	= string.format('(%s) & !(%s) & !(%s)', user_agent_mozilla5, user_agent_thunderbird, user_agent_seamonkey)
-- Mozilla based common Message-ID template
local mozilla_msgid_common	= 'Message-ID=/^\\s*<[\\dA-F]{8}\\.\\d{1,7}\\@([^>\\.]+\\.)+[^>\\.]+>$/H'
local mozilla_msgid_common_sec	= 'Message-ID=/^\\s*<[\\da-f]{8}-([\\da-f]{4}-){3}[\\da-f]{12}\\@([^>\\.]+\\.)+[^>\\.]+>$/H'
local mozilla_msgid		= 'Message-ID=/^\\s*<(3[3-9A-F]|4[\\dA-F]|5[\\dA-F])[\\dA-F]{6}\\.(\\d0){1,4}\\d\\@([^>\\.]+\\.)+[^>\\.]+>$/H'
-- Summary rule for forged Mozilla Mail Message-ID header
reconf['FORGED_MUA_MOZILLA_MAIL_MSGID'] = string.format('(%s) & (%s) & !(%s) & !(%s)', user_agent_mozilla, mozilla_msgid_common, mozilla_msgid, unusable_msgid)
reconf['FORGED_MUA_MOZILLA_MAIL_MSGID_UNKNOWN'] = string.format('(%s) & !(%s) & !(%s) & !(%s)', user_agent_mozilla, mozilla_msgid_common, mozilla_msgid, unusable_msgid)
-- Summary rule for forged Thunderbird Message-ID header
reconf['FORGED_MUA_THUNDERBIRD_MSGID'] = string.format('(%s) & (%s) & !(%s) & !(%s)', user_agent_thunderbird, mozilla_msgid_common, mozilla_msgid, unusable_msgid)
reconf['FORGED_MUA_THUNDERBIRD_MSGID_UNKNOWN'] = string.format('(%s) & !((%s) | (%s)) & !(%s) & !(%s)', user_agent_thunderbird, mozilla_msgid_common, mozilla_msgid_common_sec, mozilla_msgid, unusable_msgid)
-- Summary rule for forged Seamonkey Message-ID header
reconf['FORGED_MUA_SEAMONKEY_MSGID'] = string.format('(%s) & (%s) & !(%s) & !(%s)', user_agent_seamonkey, mozilla_msgid_common, mozilla_msgid, unusable_msgid)
reconf['FORGED_MUA_SEAMONKEY_MSGID_UNKNOWN'] = string.format('(%s) & !(%s) & !(%s) & !(%s)', user_agent_seamonkey, mozilla_msgid_common, mozilla_msgid, unusable_msgid)


-- Message id validity
local sane_msgid = 'Message-Id=/^<?[^<>\\\\ \\t\\n\\r\\x0b\\x80-\\xff]+\\@[^<>\\\\ \\t\\n\\r\\x0b\\x80-\\xff]+>?\\s*$/H'
local msgid_comment = 'Message-Id=/\\(.*\\)/H'
reconf['INVALID_MSGID'] = string.format('(%s) & !((%s) | (%s))', has_mid, sane_msgid, msgid_comment)


-- Only Content-Type header without other MIME headers
local cd = 'header_exists(Content-Disposition)'
local cte = 'header_exists(Content-Transfer-Encoding)'
local ct = 'header_exists(Content-Type)'
local mime_version = 'raw_header_exists(MIME-Version)'
local ct_text_plain = 'content_type_is_type(text) & content_type_is_subtype(plain)'
reconf['MIME_HEADER_CTYPE_ONLY'] = string.format('!(%s) & !(%s) & (%s) & !(%s) & !(%s)', cd, cte, ct, mime_version, ct_text_plain)


-- Forged Exchange messages
local msgid_dollars_ok = 'Message-Id=/[0-9a-f]{4,}\\$[0-9a-f]{4,}\\$[0-9a-f]{4,}\\@\\S+/H'
local mimeole_ms = 'X-MimeOLE=/^Produced By Microsoft MimeOLE/H'
local rcvd_with_exchange = 'Received=/with Microsoft Exchange Server/H'
reconf['RATWARE_MS_HASH'] = string.format('(%s) & !(%s) & !(%s)', msgid_dollars_ok, mimeole_ms, rcvd_with_exchange)

-- Reply-type in content-type
reconf['STOX_REPLY_TYPE'] = 'Content-Type=/text\\/plain; .* reply-type=original/H'

-- Fake Verizon headers
local fhelo_verizon = 'X-Spam-Relays-Untrusted=/^[^\\]]+ helo=[^ ]+verizon\\.net /iH'
local fhost_verizon = 'X-Spam-Relays-Untrusted=/^[^\\]]+ rdns=[^ ]+verizon\\.net /iH'
reconf['FM_FAKE_HELO_VERIZON'] = string.format('(%s) & !(%s)', fhelo_verizon, fhost_verizon)

-- Forged yahoo msgid
local at_yahoo_msgid = 'Message-Id=/\\@yahoo\\.com\\b/iH'
local at_yahoogroups_msgid = 'Message-Id=/\\@yahoogroups\\.com\\b/iH'
local from_yahoo_com = 'From=/\\@yahoo\\.com\\b/iH'
reconf['FORGED_MSGID_YAHOO'] = string.format('(%s) & !(%s)', at_yahoo_msgid, from_yahoo_com)
local r_from_yahoo_groups = 'From=/rambler.ru\\@returns\\.groups\\.yahoo\\.com\\b/iH'
local r_from_yahoo_groups_ro = 'From=/ro.ru\\@returns\\.groups\\.yahoo\\.com\\b/iH'

-- Forged The Bat! MUA headers
local thebat_mua_v1 = 'X-Mailer=/^The Bat! \\(v1\\./H'
local ctype_has_boundary = 'Content-Type=/boundary/iH'
local bat_boundary = 'Content-Type=/boundary=\\"?-{10}/H'
local mailman_21 = 'X-Mailman-Version=/\\d/H'
reconf['FORGED_MUA_THEBAT_BOUN'] = string.format('(%s) & (%s) & !(%s) & !(%s)', thebat_mua_v1, ctype_has_boundary, bat_boundary, mailman_21)

-- Two received headers with ip addresses
local double_ip_spam_1 = 'Received=/from \\[\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\] by \\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3} with/H'
local double_ip_spam_2 = 'Received=/from\\s+\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\s+by\\s+\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3};/H'
reconf['RCVD_DOUBLE_IP_SPAM'] = string.format('(%s) | (%s)', double_ip_spam_1, double_ip_spam_2)

-- Quoted reply-to from yahoo (seems to be forged)
local repto_quote = 'Reply-To=/\\".*\\"\\s*\\</H'
local from_yahoo_com = 'From=/\\@yahoo\\.com\\b/iH'
local at_yahoo_msgid = 'Message-Id=/\\@yahoo\\.com\\b/iH'
reconf['REPTO_QUOTE_YAHOO'] = string.format('(%s) & ((%s) | (%s))', repto_quote, from_yahoo_com, at_yahoo_msgid)

-- MUA definitions
local xm_gnus = 'X-Mailer=/^Gnus v/H'
local xm_msoe5 = 'X-Mailer=/^Microsoft Outlook Express 5/H'
local xm_msoe6 = 'X-Mailer=/^Microsoft Outlook Express 6/H'
local xm_mso12 = 'X-Mailer=/^Microsoft(?: Office Outlook 12\\.0| Outlook 14\\.0)/H'
local xm_cgpmapi = 'X-Mailer=/^CommuniGate Pro MAPI Connector/H'
local xm_moz4 = 'X-Mailer=/^Mozilla 4/H'
local xm_skyri = 'X-Mailer=/^SKYRiXgreen/H'
local xm_wwwmail = 'X-Mailer=/^WWW-Mail \\d/H'
local ua_gnus = 'User-Agent=/^Gnus/H'
local ua_knode = 'User-Agent=/^KNode/H'
local ua_mutt = 'User-Agent=/^Mutt/H'
local ua_pan = 'User-Agent=/^Pan/H'
local ua_xnews = 'User-Agent=/^Xnews/H'
local no_inr_yes_ref = string.format('(%s) | (%s) | (%s) | (%s) | (%s) | (%s) | (%s) | (%s) | (%s) | (%s) | (%s)', xm_gnus, xm_msoe5, xm_msoe6, xm_moz4, xm_skyri, xm_wwwmail, ua_gnus, ua_knode, ua_mutt, ua_pan, ua_xnews)
local subj_re = 'Subject=/^R[eE]:/H'
local has_ref = 'header_exists(References)'
local missing_ref = string.format('!(%s)', has_ref)
-- Fake reply (has RE in subject, but has not References header)
reconf['FAKE_REPLY_C'] = string.format('(%s) & (%s) & (%s) & !(%s)', subj_re, missing_ref, no_inr_yes_ref, xm_msoe6)

-- Mime-OLE is needed but absent (e.g. fake Outlook or fake Ecxchange)
local has_msmail_pri = 'header_exists(X-MSMail-Priority)'
local has_mimeole = 'header_exists(X-MimeOLE)'
local has_squirrelmail_in_mailer = 'X-Mailer=/SquirrelMail\\b/H'
local has_ips_php_in_mailer = 'X-Mailer=/^IPS PHP Mailer/'
local has_office12145_in_mailer = 'X-Mailer=/^Microsoft (?:Office )?Outlook 1[245]\\.0/'
reconf['MISSING_MIMEOLE'] = string.format('(%s) & !(%s) & !(%s) & !(%s) & !(%s) & !(%s) & !(%s)',
  has_msmail_pri, has_mimeole,
  has_squirrelmail_in_mailer, xm_mso12,
  xm_cgpmapi, has_ips_php_in_mailer,
  has_office12145_in_mailer)

-- Header delimiters
local yandex_from = 'From=/\\@(yandex\\.ru|yandex\\.net|ya\\.ru)/iX'
local yandex_x_envelope_from = 'X-Envelope-From=/\\@(yandex\\.ru|yandex\\.net|ya\\.ru)/iX'
local yandex_return_path = 'Return-Path=/\\@(yandex\\.ru|yandex\\.net|ya\\.ru)/iX'
local yandex_received = 'Received=/^\\s*from \\S+\\.(yandex\\.ru|yandex\\.net)/mH'
local yandex = string.format('(%s) & ((%s) | (%s) | (%s))', yandex_received, yandex_from, yandex_x_envelope_from, yandex_return_path)
-- Tabs as delimiters between header names and header values
function check_header_delimiter_tab(task, header_name)
	for _,rh in ipairs(task:get_header_full(header_name)) do
		if rh['tab_separated'] then return true end
	end
	return false
end
reconf['HEADER_FROM_DELIMITER_TAB'] = string.format('(%s) & !(%s)', 'check_header_delimiter_tab(From)', yandex)
reconf['HEADER_TO_DELIMITER_TAB'] = string.format('(%s) & !(%s)', 'check_header_delimiter_tab(To)', yandex)
reconf['HEADER_CC_DELIMITER_TAB'] = string.format('(%s) & !(%s)', 'check_header_delimiter_tab(Cc)', yandex)
reconf['HEADER_REPLYTO_DELIMITER_TAB'] = string.format('(%s) & !(%s)', 'check_header_delimiter_tab(Reply-To)', yandex)
reconf['HEADER_DATE_DELIMITER_TAB'] = string.format('(%s) & !(%s)', 'check_header_delimiter_tab(Date)', yandex)
-- Empty delimiters between header names and header values
function check_header_delimiter_empty(task, header_name)
	for _,rh in ipairs(task:get_header_full(header_name)) do
		if rh['empty_separator'] then return true end
	end
	return false
end
reconf['HEADER_FROM_EMPTY_DELIMITER'] = string.format('(%s)', 'check_header_delimiter_empty(From)')
reconf['HEADER_TO_EMPTY_DELIMITER'] = string.format('(%s)', 'check_header_delimiter_empty(To)')
reconf['HEADER_CC_EMPTY_DELIMITER'] = string.format('(%s)', 'check_header_delimiter_empty(Cc)')
reconf['HEADER_REPLYTO_EMPTY_DELIMITER'] = string.format('(%s)', 'check_header_delimiter_empty(Reply-To)')
reconf['HEADER_DATE_EMPTY_DELIMITER'] = string.format('(%s)', 'check_header_delimiter_empty(Date)')

-- Definitions of received headers regexp
reconf['RCVD_ILLEGAL_CHARS'] = 'Received=/[\\x80-\\xff]/X'

local MAIL_RU_Return_Path	= 'Return-path=/^\\s*<.+\\@mail\\.ru>$/iX'
local MAIL_RU_X_Envelope_From	= 'X-Envelope-From=/^\\s*<.+\\@mail\\.ru>$/iX'
local MAIL_RU_From		= 'From=/\\@mail\\.ru>?$/iX'
local MAIL_RU_Received		= 'Received=/from mail\\.ru \\(/mH'

reconf['FAKE_RECEIVED_mail_ru'] = string.format('(%s) & !(((%s) | (%s)) & (%s))', MAIL_RU_Received, MAIL_RU_Return_Path, MAIL_RU_X_Envelope_From, MAIL_RU_From)

local GMAIL_COM_Return_Path	= 'Return-path=/^\\s*<.+\\@gmail\\.com>$/iX'
local GMAIL_COM_X_Envelope_From	= 'X-Envelope-From=/^\\s*<.+\\@gmail\\.com>$/iX'
local GMAIL_COM_From		= 'From=/\\@gmail\\.com>?$/iX'

local UKR_NET_Return_Path	= 'Return-path=/^\\s*<.+\\@ukr\\.net>$/iX'
local UKR_NET_X_Envelope_From	= 'X-Envelope-From=/^\\s*<.+\\@ukr\\.net>$/iX'
local UKR_NET_From		= 'From=/\\@ukr\\.net>?$/iX'

local RECEIVED_smtp_yandex_ru_1	= 'Received=/from \\[\\d+\\.\\d+\\.\\d+\\.\\d+\\] \\((port=\\d+ )?helo=smtp\\.yandex\\.ru\\)/iX'
local RECEIVED_smtp_yandex_ru_2	= 'Received=/from \\[UNAVAILABLE\\] \\(\\[\\d+\\.\\d+\\.\\d+\\.\\d+\\]:\\d+ helo=smtp\\.yandex\\.ru\\)/iX'
local RECEIVED_smtp_yandex_ru_3	= 'Received=/from \\S+ \\(\\[\\d+\\.\\d+\\.\\d+\\.\\d+\\]:\\d+ helo=smtp\\.yandex\\.ru\\)/iX'
local RECEIVED_smtp_yandex_ru_4	= 'Received=/from \\[\\d+\\.\\d+\\.\\d+\\.\\d+\\] \\(account \\S+ HELO smtp\\.yandex\\.ru\\)/iX'
local RECEIVED_smtp_yandex_ru_5	= 'Received=/from smtp\\.yandex\\.ru \\(\\[\\d+\\.\\d+\\.\\d+\\.\\d+\\]\\)/iX'
local RECEIVED_smtp_yandex_ru_6	= 'Received=/from smtp\\.yandex\\.ru \\(\\S+ \\[\\d+\\.\\d+\\.\\d+\\.\\d+\\]\\)/iX'
local RECEIVED_smtp_yandex_ru_7	= 'Received=/from \\S+ \\(HELO smtp\\.yandex\\.ru\\) \\(\\S+\\@\\d+\\.\\d+\\.\\d+\\.\\d+\\)/iX'
local RECEIVED_smtp_yandex_ru_8	= 'Received=/from \\S+ \\(HELO smtp\\.yandex\\.ru\\) \\(\\d+\\.\\d+\\.\\d+\\.\\d+\\)/iX'
local RECEIVED_smtp_yandex_ru_9	= 'Received=/from \\S+ \\(\\[\\d+\\.\\d+\\.\\d+\\.\\d+\\] helo=smtp\\.yandex\\.ru\\)/iX'

reconf['FAKE_RECEIVED_smtp_yandex_ru'] = string.format('(((%s) & ((%s) | (%s))) | ((%s) & ((%s) | (%s))) | ((%s) & ((%s) | (%s)))) & (%s) | (%s) | (%s) | (%s) | (%s) | (%s) | (%s) | (%s) | (%s)', MAIL_RU_From, MAIL_RU_Return_Path, MAIL_RU_X_Envelope_From, GMAIL_COM_From, GMAIL_COM_Return_Path, GMAIL_COM_X_Envelope_From, UKR_NET_From, UKR_NET_Return_Path, UKR_NET_X_Envelope_From, RECEIVED_smtp_yandex_ru_1, RECEIVED_smtp_yandex_ru_2, RECEIVED_smtp_yandex_ru_3, RECEIVED_smtp_yandex_ru_4, RECEIVED_smtp_yandex_ru_5, RECEIVED_smtp_yandex_ru_6, RECEIVED_smtp_yandex_ru_7, RECEIVED_smtp_yandex_ru_8, RECEIVED_smtp_yandex_ru_9)

reconf['FORGED_GENERIC_RECEIVED'] =	'Received=/^\\s*(.+\\n)*from \\[\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\] by (([\\w\\d-]+\\.)+[a-zA-Z]{2,6}|\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}); \\w{3}, \\d+ \\w{3} 20\\d\\d \\d\\d\\:\\d\\d\\:\\d\\d [+-]\\d\\d\\d0/X'

reconf['FORGED_GENERIC_RECEIVED2'] =	'Received=/^\\s*(.+\\n)*from \\[\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\] by ([\\w\\d-]+\\.)+[a-z]{2,6} id [\\w\\d]{12}; \\w{3}, \\d+ \\w{3} 20\\d\\d \\d\\d\\:\\d\\d\\:\\d\\d [+-]\\d\\d\\d0/X'

reconf['FORGED_GENERIC_RECEIVED3'] =	'Received=/^\\s*(.+\\n)*by \\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3} with SMTP id [a-zA-Z]{14}\\.\\d{13};[\\r\\n\\s]*\\w{3}, \\d+ \\w{3} 20\\d\\d \\d\\d\\:\\d\\d\\:\\d\\d [+-]\\d\\d\\d0 \\(GMT\\)/X'

reconf['FORGED_GENERIC_RECEIVED4'] =	'Received=/^\\s*(.+\\n)*from localhost by \\S+;\\s+\\w{3}, \\d+ \\w{3} 20\\d\\d \\d\\d\\:\\d\\d\\:\\d\\d [+-]\\d\\d\\d0[\\s\\r\\n]*$/X'

rspamd_config.FORGED_GENERIC_RECEIVED5 = function (task)
	local regexp_text = '^\\s*from \\[(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3})\\].*\\n(.+\\n)*\\s*from \\1 by \\S+;\\s+\\w{3}, \\d+ \\w{3} 20\\d\\d \\d\\d\\:\\d\\d\\:\\d\\d [+-]\\d\\d\\d0$'
	local re = rspamd_regexp.create_cached(regexp_text, 'i')
	local headers_recv = task:get_header_full('Received')
	if headers_recv then
		for _,header_r in ipairs(headers_recv) do
			if re:match(header_r['value']) then
				return true
			end
		end
	end
    return false
end

reconf['INVALID_POSTFIX_RECEIVED'] =	'Received=/ \\(Postfix\\) with ESMTP id [A-Z\\d]+([\\s\\r\\n]+for <\\S+?>)?;[\\s\\r\\n]*[A-Z][a-z]{2}, \\d{1,2} [A-Z][a-z]{2} \\d\\d\\d\\d \\d\\d:\\d\\d:\\d\\d [\\+\\-]\\d\\d\\d\\d$/X'

rspamd_config.INVALID_EXIM_RECEIVED = function (task)
	local checked = 0
	local headers_to = task:get_header_full('To')
	if headers_to then
		local headers_recv = task:get_header_full('Received')
		local regexp_text = '^[^\\n]*?<?\\S+?\\@(\\S+)>?\\|.*from \\d+\\.\\d+\\.\\d+\\.\\d+ \\(HELO \\S+\\)[\\s\\r\\n]*by \\1 with esmtp \\(\\S*?[\\?\\@\\(\\)\\s\\.\\+\\*\'\'\\/\\\\,]\\S*\\)[\\s\\r\\n]+id \\S*?[\\)\\(<>\\/\\\\,\\-:=]'
		local re = rspamd_regexp.create_cached(regexp_text, 's')
		if headers_recv then
			for _,header_to in ipairs(headers_to) do
				for _,header_r in ipairs(headers_recv) do
					if re:match(header_to['value'].."|"..header_r['value']) then
        		        return true
        			end
				end
				checked = checked + 1
				if checked > 5 then
					-- Stop on 5 rcpt
					return false
				end
			end
		end
	end
	return false
end

rspamd_config.INVALID_EXIM_RECEIVED2 = function (task)
	local checked = 0
	local headers_to = task:get_header_full('To')
	if headers_to then
		local headers_recv = task:get_header_full('Received')
		local regexp_text = '^[^\\n]*?<?\\S+?\\@(\\S+)>?\\|.*from \\d+\\.\\d+\\.\\d+\\.\\d+ \\(HELO \\S+\\)[\\s\\r\\n]*by \\1 with esmtp \\([A-Z]{9,12} [A-Z]{5,6}\\)[\\s\\r\\n]+id [a-zA-Z\\d]{6}-[a-zA-Z\\d]{6}-[a-zA-Z\\d]{2}[\\s\\r\\n]+'
		local re = rspamd_regexp.create_cached(regexp_text, 's')
		if headers_recv then
			for _,header_to in ipairs(headers_to) do
				for _,header_r in ipairs(headers_recv) do
					if re:match(header_to['value'].."|"..header_r['value']) then
        		        return true
        			end
				end
				checked = checked + 1
				if checked > 5 then
					-- Stop on 5 rcpt
					return false
				end
			end
		end
	end
	return false
end
