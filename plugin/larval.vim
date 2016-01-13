" larval.vim - Text objects for l and r values
" Author: Lucas Groenendaal <groenendaal92@gmail.com>

if exists("g:loaded_larval") || &cp || v:version < 700
    finish
endif
let g:loaded_larval = 1

augroup larval
    autocmd!
    autocmd FileType vim
                \ let b:larval_assignment_regex = '\vlet\s+(%(.:)?(.{-}))\s*[+-.]?\=\s*' |
                \ let b:larval_rval = '\v([^|]*(\|\|)?)*(\n|\|)(^\s*\\([^|]*(\|\|)?)*(\n|\|))*'
    autocmd FileType php
                \ let b:larval_assignment_regex = '\v(\$(\k+)).{-}\s*[+-.]?\=\s*' |
                \ let b:larval_rval = '\v([^;]|\n)*;'
augroup END

function! s:get_assignment_bounds(assignment_start, flags1, assignment_end, flags2)
    let w = winsaveview()
    let assignment_start = s:searchpos_ignore_syntax(a:assignment_start, a:flags1)
    " Going into visual mode makes it so the cursor can go one spot past the
    " last character
    normal! v
    let assignment_end = s:searchpos_ignore_syntax(a:assignment_end, a:flags2)
    normal! v
    call winrestview(w)
    return [assignment_start, assignment_end]
endfunction

function! s:valid_assignment_bounds(assignment_bounds)
    return a:assignment_bounds[0][0] && a:assignment_bounds[1][0]
endfunction

function! s:getcursor_loc()
    return [line('.'), col('.')]
endfunction

function! s:move_left()
    if col('.') == 1
        normal! ge
    else
        normal! h
    endif
endfunction

function! s:shrink_rval(col)
    " We assume that if our cursor was not on the newline past the last
    " character on the current line, that our cursor is on some character that
    " marks the end of the r-value. So move the cursor one to the left to not
    " include the delimeter in the selection.
    if a:col != col('$')
        let saved_unnamed_register = @@
        call s:move_left()
        normal! vy
        while match(@@, '\s') != -1
            call s:move_left()
            normal! vy
        endwhile
        let @@ = saved_unnamed_register
    endif
endfunction

" val_type c [1, 2, 3, 4] where:
" 1 - around lval
" 2 - inner lval
" 3 - around rval
" 4 - inner rval
function! s:larval(val_type)
    let assignment_regex = b:larval_assignment_regex.b:larval_rval
    let assignment_bounds = s:get_assignment_bounds(assignment_regex, 'bcW', b:larval_rval, 'eW')
    if !(s:valid_assignment_bounds(assignment_bounds) && s:inside_bounds(s:getcursor_loc(), assignment_bounds))
        let assignment_bounds_save = assignment_bounds
        let assignment_bounds = s:get_assignment_bounds(assignment_regex, 'W', b:larval_rval, 'eW')
        if !s:valid_assignment_bounds(assignment_bounds)
            let assignment_bounds = assignment_bounds_save
        endif
    endif
    if s:valid_assignment_bounds(assignment_bounds)
        " Move to beginning of assignment
        call cursor(assignment_bounds[0])
        if a:val_type >= 3
            " 3 - 3 == 0 == around, 4 - 3 == 1 == inner
            let is_inner = a:val_type - 3
            " TODO: Consider modifying the get_assignment_bounds() function so
            " it can be used here to get the start and end of the rval.
            " Go to start of rval. We do a regular search because the rval
            " could start as a string and our searchpos_ignore_syntax() function
            " would bypass it.
            let start_pos = searchpos(b:larval_assignment_regex.'\zs')
            " Going into visual mode allows us to put the cursor on the newline past
            " the last character. Knowing this helps us determine whether or not to
            " shrink the rval.
            normal! v
            let end_pos = s:searchpos_ignore_syntax(b:larval_rval, 'e')
            normal! v
            if is_inner
                call s:shrink_rval(end_pos[1])
            endif
            let end_pos = s:getcursor_loc()
            call cursor(start_pos)
            normal! v
            call cursor(end_pos)
        else
            " Copy the left part of the assignment
            normal! v
            call search(b:larval_assignment_regex, 'eW')
            let saved_unnamed_register = @@
            normal! y
            let assignment = @@
            let @@ = saved_unnamed_register
            " Pull out the value we're interested in
            let value = '\V' . escape(substitute(assignment, b:larval_assignment_regex, '\'.a:val_type, ''), '\')
            let value = substitute(value, '\n', '\\n', 'g')
            " Visually select the value
            if search(value, 'c')
                normal! v
                call search(value, 'ce')
            endif
        endif
    endif
endfunction

" Like the searchpos() function but ignores search matches inside comments and
" strings.
function! s:searchpos_ignore_syntax(pattern, flags)
    let first_search_pos_set = 0
    if search(a:pattern, a:flags)
        let cur_search_pos = s:getcursor_loc()
        let first_search_pos = cur_search_pos
        if !(s:inside_syntax('Comment') || s:inside_syntax('String'))
            return cur_search_pos
        endif
        while search(a:pattern, a:flags)
            let old_search_pos = cur_search_pos
            let cur_search_pos = s:getcursor_loc()
            if !(s:inside_syntax('Comment') || s:inside_syntax('String'))
                return cur_search_pos
            endif
            " Ensures sure we don't loop infinitely. first_search_pos prevents
            " the situation where a we do a search() with the 'w' flag but all
            " the search terms are inside a comment or string. old_search_pos
            " + cur_search_pos prevents the situation where we search with the
            " 'c' flag and land on something inside a string or comment or the
            " 'W' flag and the last match in the buffer is a comment or string
            " at the end of the file.
            if old_search_pos == cur_search_pos || first_search_pos == cur_search_pos
                call search(a:pattern, substitute(a:flags, 'c', '', 'g'))
                if s:getcursor_loc() == cur_search_pos
                    break
                endif
            endif
        endwhile
    endif
    return [0, 0]
endfunction

function! s:inside_syntax(syn_name)
    return synIDattr(synID(line('.'), col('.'), 0), 'name') =~? a:syn_name
endfunction

function! s:inside_bounds(pos, bounds)
    let pos_line = a:pos[0]
    let pos_col = a:pos[1]
    let start_line = a:bounds[0][0]
    let start_col = a:bounds[0][1]
    let end_line = a:bounds[1][0]
    let end_col = a:bounds[1][1]
    if start_line == end_line
        return start_col <= pos_col && pos_col <= end_col && start_line == pos_line
    else
        return start_line <= pos_line && pos_line <= end_line
    endif
endfunction

onoremap <silent> <Plug>LarvalAroundLval :<C-u>call <SID>larval(1)<CR>
xnoremap <silent> <Plug>LarvalAroundLval :<C-u>call <SID>larval(1)<CR>
onoremap <silent> <Plug>LarvalInnerLval  :<C-u>call <SID>larval(2)<CR>
xnoremap <silent> <Plug>LarvalInnerLval  :<C-u>call <SID>larval(2)<CR>
onoremap <silent> <Plug>LarvalAroundRval :<C-u>call <SID>larval(3)<CR>
xnoremap <silent> <Plug>LarvalAroundRval :<C-u>call <SID>larval(3)<CR>
onoremap <silent> <Plug>LarvalInnerRval  :<C-u>call <SID>larval(4)<CR>
xnoremap <silent> <Plug>LarvalInnerRval  :<C-u>call <SID>larval(4)<CR>

function! s:create_maps(plug_around, plug_inner, is_lval)
    if !(hasmapto(a:plug_around, 'ov') || hasmapto(a:plug_inner, 'ov'))
        let lhs = (a:is_lval ? 'l' : 'r')
        for i in range(0, 1)
            if mapcheck("a".lhs, 'o') ==# '' && mapcheck("i".lhs, 'o') ==# ''
                execute "omap a".lhs." ".a:plug_around
                execute "xmap a".lhs." ".a:plug_around
                execute "omap i".lhs." ".a:plug_inner
                execute "xmap i".lhs." ".a:plug_inner
                break
            endif
            let lhs = lhs . 'v'
        endfor
    endif
endfunction

if !exists('g:larval_no_mappings')
    call s:create_maps('<Plug>LarvalAroundLval', '<Plug>LarvalInnerLval', 1)
    call s:create_maps('<Plug>LarvalAroundRval', '<Plug>LarvalInnerRval', 0)
endif

