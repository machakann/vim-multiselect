" TODO: Implement ChainedTask
" TODO: Implement EventChain
let s:ClassSys = multiselect#ClassSys#_import()
let s:Errors = multiselect#Errors#_import()
let s:TRUE = 1
let s:FALSE = 0
let s:ON = 1
let s:OFF = 0
let s:BUILTINEVENTS = getcompletion('', 'event')

let s:timertable = {}
let s:eventtable = {}
augroup multiselect
	autocmd!
augroup END

function! multiselect#Schedule#_import() abort "{{{
	return s:Schedule
endfunction "}}}

" Switch class {{{
unlockvar! s:Switch
let s:Switch = {
	\	'__CLASS__': 'Switch',
	\	'__switch__': {
	\		'state': s:ON,
	\		'skipcount': -1,
	\		}
	\	}
function! s:Switch() abort "{{{
	return deepcopy(s:Switch)
endfunction "}}}
function! s:Switch.on() abort "{{{
	let self.__switch__.state = s:ON
	let self.__switch__.skipcount = -1
	return self
endfunction "}}}
function! s:Switch.off() abort "{{{
	let self.__switch__.state = s:OFF
	let self.__switch__.skipcount = -1
	return self
endfunction "}}}
function! s:Switch.skip(...) abort "{{{
	let n = get(a:000, 0, 1)
	if n <= 0
		return self
	endif
	call self.off()
	let self.__switch__.skipcount = n
	return self
endfunction "}}}
function! s:Switch.isactive() abort "{{{
	return self.__switch__.state
endfunction "}}}
function! s:Switch._skipsthistime() abort "{{{
	if self.isactive()
		return s:FALSE
	endif
	if self.__switch__.skipcount > 0
		let self.__switch__.skipcount -= 1
		if self.__switch__.skipcount == 0
			call self.on()
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
	if self.__counter__.repeat == 0
		return s:TRUE
	elseif self.__counter__.repeat < 0
		return s:FALSE
	endif
	return self.leftcount() == 0
endfunction "}}}
function! s:Counter._finish() abort "{{{
	let left = self.leftcount()
	if left < 0
		call self.repeat(0)
	else
		call self._tick(left)
	endif
	return self
endfunction "}}}
lockvar! s:Counter
"}}}
" Task class {{{
unlockvar! s:Task
let s:Task = {
	\	'__CLASS__': 'Task',
	\	'_orderlist': [],
	\	}
function! s:Task() abort "{{{
	return deepcopy(s:Task)
endfunction "}}}
function! s:Task.trigger() abort "{{{
	for [kind, expr] in self._orderlist
		if kind is# 'call'
			call call('call', expr)
		elseif kind is# 'execute'
			execute expr
		endif
	endfor
	return self
endfunction "}}}
function! s:Task.call(func, args, ...) abort "{{{
	let order = ['call', [a:func, a:args] + a:000]
	call add(self._orderlist, order)
	return self
endfunction "}}}
function! s:Task.execute(cmd) abort "{{{
	let order = ['execute', a:cmd]
	call add(self._orderlist, order)
	return self
endfunction "}}}
function! s:Task.clear() abort "{{{
	call filter(self._orderlist, 0)
	return self
endfunction "}}}
function! s:Task.clone() abort "{{{
	let clone = deepcopy(self)
	let clone._orderlist = copy(self._orderlist)
	return clone
endfunction "}}}
lockvar! s:Task
"}}}
" TaskGroup class {{{
let s:TaskGroup = {
	\	'__CLASS__': 'TaskGroup',
	\	'__taskgroup__': {
	\		'Constructor': function('s:Task'),
	\		},
	\	'_orderlist': [],
	\	}
function! s:TaskGroup(...) abort "{{{
	let taskgroup = deepcopy(s:TaskGroup)
	if a:0 > 0
		let taskgroup.__taskgroup__.Constructor = a:1
	endif
	return taskgroup
endfunction "}}}
function! s:TaskGroup.trigger() abort "{{{
	for task in self._orderlist
		call task.trigger()
	endfor
	return self
endfunction "}}}
function! s:TaskGroup.call(func, args, ...) abort "{{{
	let task = self.__taskgroup__.Constructor()
	call call(task.call, [a:func, a:args] + a:000, task)
	call self.add(task)
	return task
endfunction "}}}
function! s:TaskGroup.execute(cmd) abort "{{{
	let task = self.__taskgroup__.Constructor()
	call call(task.execute, [a:cmd], task)
	call self.add(task)
	return task
endfunction "}}}
function! s:TaskGroup.add(task) abort "{{{
	let t_task = type(a:task)
	if t_task is v:t_dict
		call add(self._orderlist, a:task)
	elseif t_task is v:t_list
		call extend(self._orderlist, a:task)
	else
		call s:Errors.InvalidArgument('TaskGroup.add', [a:task])
	endif
	return a:task
endfunction "}}}
function! s:TaskGroup.clear() abort "{{{
	call filter(self._orderlist, 0)
	return self
endfunction "}}}
"}}}
" TimerTask class (inherits Counter and Task classes) {{{
unlockvar! s:TimerTask
let s:TimerTask = {
	\	'__CLASS__': 'TimerTask',
	\	'_id': -1,
	\	}
function! s:TimerTask() abort "{{{
	let counter = s:Counter(1)
	let task = s:Task()
	let timertask = deepcopy(s:TimerTask)
	let super = s:ClassSys.inherit(task, counter)
	return s:ClassSys.inherit(timertask, super)
endfunction "}}}
function! s:TimerTask.trigger() abort "{{{
	call s:ClassSys.super(self, 'Task').trigger()
	call self._tick()
	if self.hasdone()
		call self.stop()
	endif
	return self
endfunction "}}}
function! s:TimerTask.clone() abort "{{{
	let clone = s:ClassSys.super(self, 'Task').clone()
	let clone._id = -1
	return clone
endfunction "}}}
function! s:TimerTask.initialize() abort "{{{
	call self.stop().clear()
	let self._id = -1
	call self.repeat()
	return self
endfunction "}}}
function! s:TimerTask.start(time, ...) abort "{{{
	call self.stop()
	let options = get(a:000, 0, {})
	if !has_key(options, 'repeat')
		let options.repeat = self.leftcount()
	endif
	let id = timer_start(a:time, function('s:timercall'), options)
	let self._id = id
	let s:timertable[string(id)] = self
	call self.repeat(options.repeat)
	return self
endfunction "}}}
function! s:TimerTask.stop() abort "{{{
	if self._id < 0
		return self
	endif
	let idstr = string(self._id)
	if has_key(s:timertable, idstr)
		call remove(s:timertable, idstr)
	endif
	if self.leftcount() != 0
		call timer_stop(self._id)
	endif
	return self
endfunction "}}}
function! s:timercall(id) abort "{{{
	if !has_key(s:timertable, string(a:id))
		return
	endif
	let timertask = s:timertable[string(a:id)]
	call timertask.trigger()
endfunction "}}}
lockvar! s:TimerTask
"}}}
" EventTask class (inherits Switch, Counter and Task classes) {{{
unlockvar! s:EventTask
let s:EventTask = {
	\	'__CLASS__': 'EventTask',
	\	}
function! s:EventTask() abort "{{{
	let switch = s:Switch()
	let counter = s:Counter(-1)
	let task = s:Task()
	let eventtask = deepcopy(s:EventTask)
	let super = s:ClassSys.inherit(counter, switch)
	let super = s:ClassSys.inherit(task, super)
	return s:ClassSys.inherit(eventtask, super)
endfunction "}}}
function! s:EventTask.trigger() abort "{{{
	if self._skipsthistime()
		return self
	endif
	call s:ClassSys.super(self, 'Task').trigger()
	call self._tick()
	return self
endfunction "}}}
function! s:EventTask.finish() abort "{{{
	return self._finish()
endfunction "}}}
lockvar! s:EventTask
"}}}
" Event class (inherits Switch and TaskGroup classes) {{{
unlockvar! s:Event
let s:Event = {
	\	'__CLASS__': 'Event',
	\	'name': '',
	\	}
function! s:Event(name) abort "{{{
	let switch = s:Switch()
	let taskgroup = s:TaskGroup(function('s:EventTask'))
	let event = deepcopy(s:Event)
	let super = s:ClassSys.inherit(taskgroup, switch)
	let event = s:ClassSys.inherit(event, super)
	let event.name = a:name
	if count(s:BUILTINEVENTS, a:name) != 0
		" Built-in autocmd
		if !has_key(s:eventtable, a:name)
			let s:eventtable[a:name] = []
			augroup multiselect
				execute printf('autocmd %s * call s:doautocmd("%s")', a:name, a:name)
			augroup END
		endif
		call add(s:eventtable[a:name], event)
	else
		" User autocmd
		call event.call(function('s:douserautocmd'), [a:name])
	endif
	return event
endfunction "}}}
function! s:Event.trigger() abort "{{{
	call self.sweep()
	if self._skipsthistime()
		return self
	endif
	call s:ClassSys.super(self, 'TaskGroup').trigger()
	return self
endfunction "}}}
function! s:Event.add(task) abort "{{{
	call self.sweep()
	call s:ClassSys.super(self, 'TaskGroup').add(a:task)
endfunction "}}}
function! s:Event.sweep() abort "{{{
	call filter(self._orderlist, {_, task -> !task.hasdone()})
	return self
endfunction "}}}
function! s:doautocmd(name) abort "{{{
	let event = s:eventtable[a:name]
	for event in s:eventtable[a:name]
		call event.trigger()
	endfor
endfunction "}}}
function! s:douserautocmd(name) abort "{{{
	if !exists('#User#' . a:name)
		return
	endif
	execute 'doautocmd <nomodeline> User ' . a:name
endfunction "}}}
lockvar! s:Event
"}}}

" Schedule module {{{
unlockvar! s:Schedule
let s:Schedule = {
	\	'__MODULE__': 'Schedule',
	\	'Switch': function('s:Switch'),
	\	'Counter': function('s:Counter'),
	\	'Task': function('s:Task'),
	\	'TaskGroup': function('s:TaskGroup'),
	\	'TimerTask': function('s:TimerTask'),
	\	'EventTask': function('s:EventTask'),
	\	'Event': function('s:Event'),
	\	}
lockvar! s:Schedule
"}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
