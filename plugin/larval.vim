" Assignment regex's
augroup larval
    autocmd!
    autocmd FileType vim
                \ let b:larval_assignment_regex = '\vlet\s+(%(.:)?(.{-}))\s*[+-.]?\=\s*(([^|]*%(\n\s*\\[^|]*)*))'
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
        let search_bounds_save = search_bounds
        let search_bounds = s:get_search_bounds(assignment_regex, 0)
        if !search_bounds[0][0]
            let search_bounds = search_bounds_save
        endif
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
            call search(value, 'ce')
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

