" Assignment regex's
augroup larval
    autocmd!
    autocmd FileType vim
                \ let b:larval_assignment_regex = '\v\s*let\s+(%(.:)=(.{-}))\s*\=\s*(([^|]*%(\n\s*\\[^|]*)*))'
    autocmd FileType php
                \ let b:larval_assignment_regex = '\v\s*(\$(\k+)).{-}\=\s*((%(.|\n){-});)'
augroup END

" val_type c [1, 2, 3, 4] where:
" 1 - around lval
" 2 - inner lval
" 3 - around rval
" 4 - inner rval
function! s:larval(val_type)
    let assignment_regex = b:larval_assignment_regex
    let search_bounds = s:get_search_bounds(assignment_regex, 1)
    if !(search_bounds[0][0] && s:inside_bounds(s:get_pos(), search_bounds))
        let search_bounds = s:get_search_bounds(assignment_regex, 0)
    endif

    if search_bounds[0][0]
        " Copy the entire assignment
        call cursor(search_bounds[0])
        normal! v
        call cursor(search_bounds[1])
        let saved_unnamed_register = @@
        normal! y
        let assignment = @@
        let @@ = saved_unnamed_register
        " Pull out the value we're interested in
        let value = '\V' . escape(substitute(assignment, assignment_regex, '\'.a:val_type, ''), '\')
        let value = substitute(value, '\n', '\\n', 'g')
        " Visually select the value
        if search(value, 'c')
            normal! v
            call search(value, 'e')
        endif
    endif
endfunction

function! s:get_search_bounds(regex, search_backwards)
    let w = winsaveview()
    if a:search_backwards
        let first_flag = 'b'
        let second_flag = 'e'
    else
        let first_flag = 'e'
        let second_flag = 'b'
    endif
    let start = searchpos(a:regex, first_flag.'cW')
    if start[0]
        let end = searchpos(a:regex, second_flag.'cW')
        call winrestview(w)
        return [start, end]
    endif
    return [[0, 0], [0, 0]]
endfunction

function! s:inside_bounds(pos, bounds)
    let pos_line = a:pos[0]
    let pos_col = a:pos[1]
    let start_line = a:bounds[0][0]
    let start_col = a:bounds[0][1]
    let end_line = a:bounds[1][0]
    let end_col = a:bounds[1][1]

    return (start_line <= pos_line && pos_line <= end_line) &&
                \ (start_col <= pos_col && pos_col <= end_col)
endfunction

function! s:get_pos()
    return [line('.'), col('.')]
endfunction

onoremap <silent> <Plug>LarvalAroundLval :<C-u>call <SID>larval(1)<CR>
xnoremap <silent> <Plug>LarvalAroundLval :<C-u>call <SID>larval(1)<CR>
onoremap <silent> <Plug>LarvalInnerLval  :<C-u>call <SID>larval(2)<CR>
xnoremap <silent> <Plug>LarvalInnerLval  :<C-u>call <SID>larval(2)<CR>
onoremap <silent> <Plug>LarvalAroundRval :<C-u>call <SID>larval(3)<CR>
xnoremap <silent> <Plug>LarvalAroundRval :<C-u>call <SID>larval(3)<CR>
onoremap <silent> <Plug>LarvalInnerRval  :<C-u>call <SID>larval(4)<CR>
xnoremap <silent> <Plug>LarvalInnerRval  :<C-u>call <SID>larval(4)<CR>

function! s:create_map(plug, around, is_lval)
    if !hasmapto(a:plug, 'ov')
        let lhs = (a:around ? 'a' : 'i') . (a:is_lval ? 'l' : 'r')
        for i in range(0, 1)
            if mapcheck(lhs, 'o') ==# ''
                execute "omap ".lhs." ".a:plug
                execute "xmap ".lhs." ".a:plug
                break
            endif
            let lhs = lhs . 'v'
        endfor
    endif
endfunction

if !exists('g:larval_no_mappings')
    call s:create_map('<Plug>LarvalAroundLval', 1, 1)
    call s:create_map('<Plug>LarvalInnerLval',  0, 1)
    call s:create_map('<Plug>LarvalAroundRval', 1, 0)
    call s:create_map('<Plug>LarvalInnerRval',  0, 0)
endif

