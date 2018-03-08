" TODO: Implement NeatTask.preprocess()/.postprocess()
let s:ClassSys = multiselect#ClassSys#_import()
let s:TRUE = 1
let s:FALSE = 0
let s:ON = 1
let s:OFF = 0
let s:DEFAULTAUGROUP = 'multiselect'

" Error list {{{
function! s:InvalidTriggers(triggerlist) abort "{{{
	return printf('multiselect: Invalid triggers for a task, %s',
							\ string(a:triggerlist))
endfunction "}}}
"}}}



" Event class {{{
let s:Event = {
	\		'table': {},
	\	}

function! s:Event.add(augroup, event, pat, task) abort "{{{
	if !has_key(self.table, a:augroup)
		let self.table[a:augroup] = {}
	endif
	if !has_key(self.table[a:augroup], a:event)
		let self.table[a:augroup][a:event] = {}
	endif
	if !has_key(self.table[a:augroup][a:event], a:pat)
		let self.table[a:augroup][a:event][a:pat] = []
		call s:_autocmd(a:augroup, a:event, a:pat)
	endif
	call add(self.table[a:augroup][a:event][a:pat], a:task)
endfunction "}}}

function! s:Event.remove(augroup, event, pat, task) abort "{{{
	if !has_key(s:Event.table, a:augroup) || !has_key(s:Event.table[a:augroup], a:event)
			\ || !has_key(s:Event.table[a:augroup][a:event], a:pat)
		return
	endif

	call filter(self.table[a:augroup][a:event][a:pat],
						\ 'v:val isnot a:task && !v:val.hasdone()')

	if empty(s:Event.table[a:augroup][a:event][a:pat])
		call remove(s:Event.table[a:augroup][a:event], a:pat)
		execute printf('autocmd! %s %s %s', a:augroup, a:event, a:pat)

		if empty(s:Event.table[a:augroup][a:event])
			call remove(s:Event.table[a:augroup], a:event)

			if empty(s:Event.table[a:augroup])
				call remove(s:Event.table, a:augroup)
			endif
		endif
	endif
endfunction "}}}

function! s:_autocmd(augroup, event, pat) abort "{{{
	let autocmd = printf("autocmd %s %s call s:_doautocmd('%s', '%s', '%s')",
											\ a:event, a:pat, a:augroup, a:event, a:pat)

	execute 'augroup ' . a:augroup
		execute autocmd
	augroup END
endfunction "}}}

function! s:_doautocmd(augroup, event, pat) abort "{{{
	if !has_key(s:Event.table, a:augroup) || !has_key(s:Event.table[a:augroup], a:event)
			\ || !has_key(s:Event.table[a:augroup][a:event], a:pat)
		return
	endif

	for task in s:Event.table[a:augroup][a:event][a:pat]
		call task.trigger()
	endfor
endfunction "}}}
"}}}



" Timer class {{{
let s:Timer = {
	\		'table': {},
	\	}

function! s:Timer.add(time, task) abort "{{{
	let id = timer_start(a:time, function('s:_timercall'), {'repeat': -1})
	let self.table[string(id)] = a:task
	return id
endfunction "}}}

function! s:Timer.remove(id) abort "{{{
	let idstr = string(a:id)
	if has_key(self.table, idstr)
		call remove(self.table, idstr)
	endif
	if !empty(timer_info(a:id))
		call timer_stop(a:id)
	endif
endfunction "}}}

function! s:_timercall(id) abort "{{{
	if !has_key(s:Timer.table, string(a:id))
		return
	endif
	let task = s:Timer.table[string(a:id)]
	call task.trigger()
endfunction "}}}
"}}}



" Switch class {{{
unlockvar! s:Switch
let s:Switch = {
	\	'__CLASS__': 'Switch',
	\	'__switch__': {
	\		'skipcount': 0,
	\		'skipif': [],
	\		}
	\	}
function! s:Switch() abort "{{{
	return deepcopy(s:Switch)
endfunction "}}}

function! s:Switch._on() abort "{{{
	let self.__switch__.skipcount = 0
	return self
endfunction "}}}

function! s:Switch._off() abort "{{{
	let self.__switch__.skipcount = -1
	return self
endfunction "}}}

function! s:Switch.skip(...) abort "{{{
	let self.__switch__.skipcount = max([get(a:000, 0, 1), -1])
	return self
endfunction "}}}

function! s:Switch.skipif(func, args, ...) abort "{{{
	let self.__switch__.skipif = [a:func, a:args] + a:000
endfunction "}}}

function! s:Switch._isactive() abort "{{{
	if !empty(self.__switch__.skipif)
		if call('call', self.__switch__.skipif)
			return s:FALSE
		endif
	endif
	return self.__switch__.skipcount == 0
endfunction "}}}

function! s:Switch._skipsthistime() abort "{{{
	if self._isactive()
		return s:FALSE
	endif
	if self.__switch__.skipcount > 0
		let self.__switch__.skipcount -= 1
		if self.__switch__.skipcount == 0
			call self._on()
		endif
	endif
	return s:TRUE
endfunction "}}}

lockvar! s:Switch
"}}}



" Counter class {{{
unlockvar! s:Counter
let s:Counter = {
	\	'__CLASS__': 'Counter',
	\	'__counter__': {
	\		'repeat': 1,
	\		'done': 0,
	\		'finishif': [],
	\		}
	\	}
function! s:Counter(count) abort "{{{
	let counter = deepcopy(s:Counter)
	let counter.__counter__.repeat = a:count
	return counter
endfunction "}}}

function! s:Counter.repeat(...) abort "{{{
	if a:0 > 0
		let self.__counter__.repeat = a:1
	endif
	let self.__counter__.done = 0
	return self
endfunction "}}}

function! s:Counter._tick(...) abort "{{{
	let self.__counter__.done += get(a:000, 0, 1)
endfunction "}}}

function! s:Counter.leftcount() abort "{{{
	if self.__counter__.repeat < 0
		return -1
	endif
	return max([self.__counter__.repeat - self.__counter__.done, 0])
endfunction "}}}

function! s:Counter.hasdone() abort "{{{
	if self.leftcount() == 0
		return s:TRUE
	endif

	" 'finishif' check
	if !empty(self.__counter__.finishif)
		if call('call', self.__counter__.finishif)
			return s:TRUE
		endif
	endif

	return s:FALSE
endfunction "}}}

function! s:Counter.finishif(func, args, ...) abort "{{{
	let self.__counter__.finishif = [a:func, a:args] + a:000
endfunction "}}}

lockvar! s:Counter
"}}}



" MetaTask class {{{
unlockvar! s:MetaTask
let s:MetaTask = {
	\	'__CLASS__': 'MetaTask',
	\	'_orderlist': [],
	\	}
function! s:MetaTask() abort "{{{
	return deepcopy(s:MetaTask)
endfunction "}}}

function! s:MetaTask.trigger() abort "{{{
	for [kind, expr] in self._orderlist
		if kind is# 'call'
			call call('call', expr)
		elseif kind is# 'execute'
			execute expr
		elseif kind is# 'task'
			call expr.trigger()
		endif
	endfor
	return self
endfunction "}}}

function! s:MetaTask.call(func, args, ...) abort "{{{
	let order = ['call', [a:func, a:args] + a:000]
	call add(self._orderlist, order)
	return self
endfunction "}}}

function! s:MetaTask.execute(cmd) abort "{{{
	let order = ['execute', a:cmd]
	call add(self._orderlist, order)
	return self
endfunction "}}}

function! s:MetaTask.append(task) abort "{{{
	let order = ['task', a:task]
	call add(self._orderlist, order)
	return self
endfunction "}}}

function! s:MetaTask.clear() abort "{{{
	call filter(self._orderlist, 0)
	return self
endfunction "}}}

function! s:MetaTask.clone() abort "{{{
	let clone = deepcopy(self)
	let clone._orderlist = copy(self._orderlist)
	return clone
endfunction "}}}

lockvar! s:MetaTask
"}}}



" NeatTask class (inherits Switch, Counter and MetaTask classes) {{{
unlockvar! s:NeatTask
let s:NeatTask = {
	\	'__CLASS__': 'NeatTask',
	\	}
function! s:NeatTask() abort "{{{
	let switch = s:Switch()
	let counter = s:Counter(1)
	let metatask = s:MetaTask()
	let neattask = deepcopy(s:NeatTask)
	return s:ClassSys.inherit(neattask, metatask, counter, switch)
endfunction "}}}

function! s:NeatTask.trigger() abort "{{{
	if self._skipsthistime()
		return self
	endif
	if self.hasdone()
		return self
	endif
	call s:ClassSys.super(self, 'MetaTask').trigger()
	call self._tick()
	if self.hasdone()
		call self.cancel()
	endif
	return self
endfunction "}}}

function! s:NeatTask.waitfor() abort "{{{
	return self
endfunction "}}}

function! s:NeatTask.cancel() abort "{{{
	return self
endfunction "}}}

function! s:NeatTask.isactive() abort "{{{
	return self._isactive()
endfunction "}}}

lockvar! s:NeatTask
"}}}



" Task class (inherits NeatTask class) {{{
unlockvar! s:Task
let s:Task = {
	\	'__CLASS__': 'Task',
	\	'__task__': {
	\		'Event': [],
	\		'Timer': -1,
	\		},
	\	'_state': s:OFF,
	\	'_augroup': '',
	\	}
function! s:Task(...) abort "{{{
	let neattask = s:NeatTask()
	let task = s:ClassSys.inherit(deepcopy(s:Task), neattask)
	let task._augroup = get(a:000, 0, s:DEFAULTAUGROUP)
	return task
endfunction "}}}

function! s:Task.clone() abort "{{{
	let clone = s:Task()
	let clone.__switch__ = deepcopy(self.__switch__)
	let clone.__counter__ = deepcopy(self.__counter__)
	let clone._state = s:OFF
	let clone._orderlist = copy(self._orderlist)
	return clone
endfunction "}}}

function! s:Task.waitfor(triggerlist) abort "{{{
	call self.cancel().repeat()
	let invalid = s:_invalid_triggerlist(a:triggerlist)
	if !empty(invalid)
		echoerr s:InvalidTriggers(invalid)
	endif
	let augroup = self._augroup

	let self._state = s:ON
	let events = filter(copy(a:triggerlist), 'type(v:val) is v:t_string || type(v:val) is v:t_list')
	call uniq(sort(events))
	for eventexpr in events
		let [event, pat] = s:_event_and_patterns(eventexpr)
		call s:Event.add(augroup, event, pat, self)
		call add(self.__task__.Event, [event, pat])
	endfor

	let times = filter(copy(a:triggerlist), 'type(v:val) is v:t_number')
	call filter(times, 'v:val > 0')
	if !empty(times)
		let time = min(times)
		let self.__task__.Timer = s:Timer.add(time, self)
	endif
	return self
endfunction "}}}

function! s:Task.cancel() abort "{{{
	let self._state = s:OFF
	if !empty(self.__task__.Event)
		let augroup = self._augroup
		for [event, pat] in self.__task__.Event
			call s:Event.remove(augroup, event, pat, self)
		endfor
		call filter(self.__task__.Event, 0)
	endif
	if self.__task__.Timer != -1
		let id = self.__task__.Timer
		call s:Timer.remove(id)
		let self.__task__.Timer = -1
	endif
	return self
endfunction "}}}

function! s:Task.isactive() abort "{{{
	return self._state && s:ClassSys.super(self, 'Switch')._isactive()
endfunction "}}}

function! s:Task._getid() abort "{{{
	return self.__task__.Timer
endfunction "}}}

lockvar! s:Task
"}}}



" TaskChain class (inherits Counter class) {{{
unlockvar! s:TaskChain
let s:TaskChain = {
	\	'__CLASS__': 'TaskChain',
	\	'_index': 0,
	\	'_triggerlist': [],
	\	'_orderlist': [],
	\	'_augroup': '',
	\	'_state': s:OFF,
	\	}
function! s:TaskChain(...) abort "{{{
	let counter = s:Counter(1)
	let taskchain = s:ClassSys.inherit(deepcopy(s:TaskChain), counter)
	let taskchain._augroup = get(a:000, 0, s:DEFAULTAUGROUP)
	return taskchain
endfunction "}}}

function! s:TaskChain.hook(triggerlist) abort "{{{
	let invalid = s:_invalid_triggerlist(a:triggerlist)
	if !empty(invalid)
		echoerr s:InvalidTriggers(invalid)
	endif

	let task = s:Task(self._augroup)
	let ordertask = s:NeatTask()
	let args = [a:triggerlist]
	call self._settrigger(task, args)
	call self._setorder(ordertask)
	return ordertask
endfunction "}}}

function! s:TaskChain.trigger() abort "{{{
	if self._index >= len(self._orderlist)
		return self
	endif

	let task = self._orderlist[self._index]
	call task.trigger()
	if self.hasdone()
		call self.cancel()
	elseif task.hasdone()
		call self._gonext()
	endif
	return self
endfunction "}}}

function! s:TaskChain.waitfor() abort "{{{
	call self.cancel().repeat()
	let self._state = s:ON
	let [trigger, args] = self._triggerlist[self._index]
	call call(trigger.waitfor, args, trigger)
	return self
endfunction "}}}

function! s:TaskChain.cancel() abort "{{{
	let self._state = s:OFF
	if self._index == len(self._orderlist)
		return self
	endif
	let [trigger, _] = self._triggerlist[self._index]
	let task = self._orderlist[self._index]
	call trigger.cancel()
	call task.cancel()
	return self
endfunction "}}}

function! s:TaskChain._settrigger(triggertask, args) abort "{{{
	call a:triggertask.repeat(-1)
	call a:triggertask.call(self.trigger, [], self)
	call add(self._triggerlist, [a:triggertask, a:args])
endfunction "}}}

function! s:TaskChain._setorder(ordertask) abort "{{{
	call a:ordertask.repeat(1)
	call add(self._orderlist, a:ordertask)
endfunction "}}}

function! s:TaskChain._gonext() abort "{{{
	let [trigger, _] = self._triggerlist[self._index]
	call trigger.cancel()

	let self._index += 1
	if self._index == len(self._orderlist)
		call self._tick()
		if self.hasdone()
			call self.cancel()
			return
		else
			let self._index = 0
		endif
	endif
	let [nexttrigger, args] = self._triggerlist[self._index]
	call call(nexttrigger.waitfor, args, nexttrigger)
endfunction "}}}

lockvar! s:TaskChain
"}}}



function! s:_event_and_patterns(eventexpr) abort "{{{
	let t_event = type(a:eventexpr)
	if t_event is v:t_string
		let event = a:eventexpr
		let pat = '*'
	elseif t_event is v:t_list
		let event = a:eventexpr[0]
		let pat = get(a:eventexpr, 1, '*')
	else
		echoerr s:InvalidTriggers(a:eventexpr)
	endif
	return [event, pat]
endfunction "}}}

function! s:_invalid_triggerlist(triggerlist) abort "{{{
	return filter(copy(a:triggerlist), '!s:_isvalidtriggertype(v:val)')
endfunction "}}}

function! s:_isvalidtriggertype(item) abort "{{{
	let t_trigger = type(a:item)
	if t_trigger is v:t_string || t_trigger is v:t_list || t_trigger is v:t_number
		return s:TRUE
	endif
	return s:FALSE
endfunction "}}}

function! s:augroup(name) dict abort "{{{
	let new = deepcopy(self)
	let new.Task = funcref(self.Task, [a:name])
	let new.TaskChain = funcref(self.TaskChain, [a:name])
	return new
endfunction "}}}



" Schedule module {{{
unlockvar! s:Schedule
let s:Schedule = {
	\	'__MODULE__': 'Schedule',
	\	'Switch': function('s:Switch'),
	\	'Counter': function('s:Counter'),
	\	'MetaTask': function('s:MetaTask'),
	\	'NeatTask': function('s:NeatTask'),
	\	'Task': function('s:Task'),
	\	'TaskChain': function('s:TaskChain'),
	\	'augroup': function('s:augroup'),
	\	}
lockvar! s:Schedule
"}}}

function! multiselect#Schedule#_import() abort "{{{
	return s:Schedule
endfunction "}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
