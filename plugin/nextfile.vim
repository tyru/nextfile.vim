" vim:foldmethod=marker:fen:
scriptencoding utf-8

" DOCUMENT {{{1
"==================================================
" Name: nextfile
" Version: 0.0.3
" Author:  tyru <tyru.exe@gmail.com>
" Last Change: 2009-11-11.
"
" Description:
"   open the next or previous file
"
" Change Log: {{{2
"   0.0.0: Initial upload.
"   0.0.1: add g:nf_ignore_dir
"   0.0.2: implement g:nf_ignore_ext.
" }}}2
"
"
" Usage:
"
"   MAPPING:
"       default:
"           <Leader>n - open the next file
"           <Leader>p - open the previous file
"
"   GLOBAL VARIABLES:
"       g:nf_map_next (default: '<Leader>n')
"           open the next file.
"
"       g:nf_map_previous (default: '<Leader>p')
"           open the previous file.
"
"       g:nf_include_dotfiles (default: 0)
"           if true, open the next dotfile.
"           if false, skip the next dotfile.
"
"       g:nf_open_command (default: 'edit')
"           open the (next|previous) file with this command.
"
"       g:nf_loop_files (default: 0)
"           if true, loop when reached the end.
"
"       g:nf_ignore_dir (default: 1)
"           if true, skip directory.
"
"       g:nf_ignore_ext (default: [])
"           ignore files of these extensions.
"           e.g.: "o", "obj", "exe"
"
"       g:nf_disable_if_empty_name (default: 0)
"           do not run mapping if current file name is empty.
"
"       g:nf_commands (default: see below)
"           command's names.
"           if you do not want to define some commands,
"           please leave '' in command's value.
"               e.g.: let g:nf_commands = {'NFLoadGlob': ''}
"
"           default value:
"               let g:nf_commands = {
"               \   'NFLoadGlob' : 'NFLoadGlob',
"               \   'NFNext'     : 'NFNext',
"               \   'NFPrev'     : 'NFPrev',
"               \ }
"
"   COMMANDS:
"       :NFLoadGlob
"           load globbed files.
"           this command just load files to buffers, does not edit them.
"           g:nf_include_dotfiles, g:nf_ignore_*, etc. influence globbed file's list.
"               :NFLoadGlob *   " to load all files in current directory.
"       :NFNext
"           open next file.
"           you can pass the number of loading buffers.
"       :NFPrev
"           open previous file.
"           you can pass the number of loading buffers.
"
"
"==================================================
" }}}1

" INCLUDE GUARD {{{1
if exists('g:loaded_nextfile') && g:loaded_nextfile != 0 | finish | endif
let g:loaded_nextfile = 1
" }}}1
" SAVING CPO {{{1
let s:save_cpo = &cpo
set cpo&vim
" }}}1

" GLOBAL VARIABLES {{{1
if ! exists('g:nf_map_next')
    let g:nf_map_next = '<Leader>n'
endif
if ! exists('g:nf_map_previous')
    let g:nf_map_previous = '<Leader>p'
endif
if ! exists('g:nf_include_dotfiles')
    let g:nf_include_dotfiles = 0
endif
if ! exists('g:nf_open_command')
    let g:nf_open_command = 'edit'
endif
if ! exists('g:nf_loop_files')
    let g:nf_loop_files = 0
endif
if ! exists('g:nf_ignore_dir')
    let g:nf_ignore_dir = 1
endif
if ! exists('g:nf_ignore_ext') || type(g:nf_ignore_ext) != type([])
    let g:nf_ignore_ext = []
endif
if ! exists('g:nf_disable_if_empty_name')
    let g:nf_disable_if_empty_name = 0
endif

let s:commands = {
\   'NFLoadGlob' : 'NFLoadGlob',
\   'NFNext'     : 'NFNext',
\   'NFPrev'     : 'NFPrev',
\ }
if ! exists('g:nf_commands')
    let g:nf_commands = s:commands
else
    call extend(g:nf_commands, s:commands, 'keep')
endif
unlet s:commands
" }}}1


" FUNCTION DEFINITION {{{1

func! s:Warn(msg)
    echohl WarningMsg
    echo a:msg
    echohl None
endfunc

func! s:GetListIdx(lis, elem)
    let i = 0
    while i < len(a:lis)
        if a:lis[i] ==# a:elem
            return i
        endif
        let i = i + 1
    endwhile
    throw "not found"
endfunc

func! s:Glob(expr)
    let files = split(glob(a:expr), '\n')
    " get rid of '.' and '..'
    call filter(files, 'fnamemodify(v:val, ":t") !=# "." && fnamemodify(v:val, ":t") !=# ".."')
    return files
endfunc

func! s:GetFilesList()
    " get files list
    let files = s:Glob(expand('%:p:h') . '/*')
    if g:nf_include_dotfiles
        let files += s:Glob(expand('%:p:h') . '/.*')
    endif
    if g:nf_ignore_dir
        call filter(files, '! isdirectory(v:val)')
    endif
    for ext in g:nf_ignore_ext
        call filter(files, 'fnamemodify(v:val, ":e") !=# ext')
    endfor

    " sort alphabetically
    call sort(files)

    return files
endfunc

func! s:GetIdx(files, advance)
    try
        " get current file idx
        let tailed = map(copy(a:files), 'fnamemodify(v:val, ":t")')
        let idx = s:GetListIdx(tailed, expand('%:t'))
        " move to next or previous
        let idx = a:advance ? idx + 1 : idx - 1
    catch /^not found$/
        " open the first file.
        let idx = 0
    endtry
    return idx
endfunc

func! s:OpenNextFile(advance)
    if g:nf_disable_if_empty_name && expand('%') ==# ''
        return s:Warn("current file is empty.")
    endif

    let files = s:GetFilesList()
    if empty(files) | return | endif
    let idx   = s:GetIdx(files, a:advance)
    if get(files, idx, -1) !=# -1
        " can access to files[idx]
        execute g:nf_open_command fnameescape(files[idx])
    elseif g:nf_loop_files
        let idx = idx < 0 ? idx : idx - len(files)
        execute g:nf_open_command . ' ' . fnameescape(files[idx])
    else
        call s:Warn(printf('no %s file.', a:advance ? 'next' : 'previous'))
    endif
endfunc

func! s:CmdLoadGlob()
    " TODO
endfunc

func! s:CmdNextPrev(is_next, ...)
    try
        let times = range(1, a:0 == 0 ? 1 : str2nr(a:1))
    catch
        " out of range
        return
    endtry
    for i in times
        call s:OpenNextFile(a:is_next)
    endfor
endfunc

" }}}1

" MAPPING {{{1
execute printf('nnoremap <silent><unique> %s :call <SID>OpenNextFile(1)<CR>', g:nf_map_next)
execute printf('nnoremap <silent><unique> %s :call <SID>OpenNextFile(0)<CR>', g:nf_map_previous)
" }}}1

" COMMANDS {{{1
let s:command_def = {
\   'NFLoadGlob' : ['-nargs=+', 'call s:CmdLoadGlob()'],
\   'NFNext'     : ['-nargs=?', 'call s:CmdNextPrev(1,<f-args>)'],
\   'NFPrev'     : ['-nargs=?', 'call s:CmdNextPrev(0,<f-args>)'],
\ }
for [cmd, name] in items(g:nf_commands)
    if !empty(name)
        let [opt, def] = s:command_def[cmd]
        execute printf("command %s %s %s", opt, name, def)
    endif
endfor
unlet s:command_def
" }}}1

" RESTORE CPO {{{1
let &cpo = s:save_cpo
" }}}1

