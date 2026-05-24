" 2026-dark.vim — Dark colorscheme
" Converted from VSCode 2026 Dark theme
" Source: microsoft/vscode extensions/theme-defaults/themes/2026-dark.json
" License: MIT
"
" Palette (extracted from tokenColors + editor colors):
"
"   editor.background          #121314
"   editor.foreground          #BBBEBF
"   editorLineNumber.fg        #858889
"   editorLineNumber.activeFg  #BBBEBF
"   editor.lineHighlight       #242526
"   editor.selection           #276782dd -> #276782
"   editor.findMatch           #276782
"   editorBracketMatch         #3994BC55
"   editorWidget.background    #202122
"   sidebar/panel background   #191A1B
"   border                     #2A2B2C
"   statusBar.background       #191A1B
"   statusBar.foreground       #8C8C8C
"
"   Token colors:
"   comment        #8b949e
"   constant       #79c0ff
"   string         #a5d6ff
"   keyword        #ff7b72
"   storage        #ff7b72
"   entity.name    #ffa657  (class/var/definition)
"   entity.fn      #d2a8ff
"   entity.tag     #7ee787
"   variable       #ffa657
"   variable.other #c9d1d9
"   support        #79c0ff
"   invalid        #ffa198
"   markup.deleted #ffa198
"   markup.inserted#7ee787
"   markup.changed #ffa657
"   foreground-dim #c9d1d9
"
"   UI accents:
"   blue-accent    #3994BC
"   error          #f48771
"   warning        #e5ba7d
"   git.added      #73c991
"   git.modified   #e5ba7d
"   git.deleted    #f48771

set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif
let g:colors_name = "2026-dark"

" ============================================================
" Core UI
" ============================================================
hi Normal         guifg=#BBBEBF guibg=#121314   ctermfg=250 ctermbg=233
hi NormalNC       guifg=#BBBEBF guibg=#191A1B   ctermfg=250 ctermbg=234
hi NormalFloat    guifg=#bfbfbf guibg=#202122   ctermfg=250 ctermbg=235

hi Cursor         guifg=#121314 guibg=#BBBEBF   ctermfg=233 ctermbg=250
hi CursorLine     guibg=#242526 ctermbg=235 gui=NONE cterm=NONE
hi CursorLineNr   guifg=#BBBEBF guibg=#242526   ctermfg=250 ctermbg=235  gui=NONE cterm=NONE
hi CursorColumn   guibg=#242526 ctermbg=235

hi LineNr         guifg=#858889 guibg=#121314   ctermfg=244 ctermbg=233
hi SignColumn     guifg=#858889 guibg=#121314   ctermfg=244 ctermbg=233
hi FoldColumn     guifg=#858889 guibg=#121314   ctermfg=244 ctermbg=233
hi Folded         guifg=#8C8C8C guibg=#242526   ctermfg=244 ctermbg=235  gui=italic

hi Visual         guibg=#276782  ctermbg=24
hi VisualNOS      guibg=#276782  ctermbg=24

hi StatusLine     guifg=#bfbfbf guibg=#2A2B2C   ctermfg=250 ctermbg=235  gui=bold
hi StatusLineNC   guifg=#8C8C8C guibg=#191A1B   ctermfg=244 ctermbg=234
hi WinSeparator   guifg=#2A2B2C guibg=NONE      ctermfg=235
hi VertSplit      guifg=#2A2B2C guibg=NONE      ctermfg=235

hi TabLine        guifg=#8C8C8C guibg=#191A1B   ctermfg=244 ctermbg=234  gui=NONE cterm=NONE
hi TabLineSel     guifg=#bfbfbf guibg=#121314   ctermfg=250 ctermbg=233  gui=bold
hi TabLineFill    guibg=#191A1B ctermbg=234

hi Pmenu          guifg=#bfbfbf guibg=#202122   ctermfg=250 ctermbg=235
hi PmenuSel       guifg=#bfbfbf guibg=#3994BC   ctermfg=250 ctermbg=31   gui=bold
hi PmenuSbar      guibg=#2A2B2C ctermbg=235
hi PmenuThumb     guibg=#838485 ctermbg=244

hi Search         guifg=#BBBEBF guibg=#276782   ctermfg=250 ctermbg=24
hi CurSearch      guifg=#BBBEBF guibg=#3994BC   ctermfg=250 ctermbg=31   gui=bold
hi IncSearch      guifg=#BBBEBF guibg=#3994BC   ctermfg=250 ctermbg=31   gui=bold
hi Substitute     guifg=#121314 guibg=#ffa657   ctermfg=233 ctermbg=215

hi MatchParen     guifg=#BBBEBF guibg=#3994BC   ctermfg=250 ctermbg=31   gui=bold

hi QuickFixLine   guibg=#3994BC ctermbg=31

hi ColorColumn    guibg=#242526 ctermbg=235
hi Conceal        guifg=#8C8C8C ctermfg=244

hi NonText        guifg=#555555 ctermfg=240
hi SpecialKey     guifg=#555555 ctermfg=240
hi Whitespace     guifg=#333333 ctermfg=236

hi Title          guifg=#79c0ff ctermfg=117     gui=bold
hi Question       guifg=#3994BC ctermfg=31
hi MoreMsg        guifg=#3994BC ctermfg=31
hi ModeMsg        guifg=#bfbfbf ctermfg=250     gui=bold
hi ErrorMsg       guifg=#121314 guibg=#f48771   ctermfg=233 ctermbg=210  gui=bold
hi WarningMsg     guifg=#e5ba7d ctermfg=179

hi WildMenu       guifg=#FFFFFF guibg=#297AA0   ctermfg=231 ctermbg=31   gui=bold

hi Directory      guifg=#79c0ff ctermfg=117
hi EndOfBuffer    guifg=#333333 ctermfg=236

" ============================================================
" Syntax
" ============================================================
hi Comment        guifg=#8b949e ctermfg=245     gui=italic  cterm=italic
hi SpecialComment guifg=#8b949e ctermfg=245     gui=italic  cterm=italic

hi Constant       guifg=#79c0ff ctermfg=117
hi String         guifg=#a5d6ff ctermfg=153
hi Character      guifg=#ff7b72 ctermfg=210
hi Number         guifg=#79c0ff ctermfg=117
hi Boolean        guifg=#79c0ff ctermfg=117
hi Float          guifg=#79c0ff ctermfg=117

hi Identifier     guifg=#ffa657 ctermfg=215
hi Function       guifg=#d2a8ff ctermfg=183

hi Statement      guifg=#ff7b72 ctermfg=210
hi Conditional    guifg=#ff7b72 ctermfg=210
hi Repeat         guifg=#ff7b72 ctermfg=210
hi Label          guifg=#ff7b72 ctermfg=210
hi Operator       guifg=#ff7b72 ctermfg=210
hi Keyword        guifg=#ff7b72 ctermfg=210
hi Exception      guifg=#ff7b72 ctermfg=210

hi PreProc        guifg=#ff7b72 ctermfg=210
hi Include        guifg=#ff7b72 ctermfg=210
hi Define         guifg=#ff7b72 ctermfg=210
hi Macro          guifg=#ff7b72 ctermfg=210
hi PreCondit      guifg=#ff7b72 ctermfg=210

hi Type           guifg=#79c0ff ctermfg=117
hi StorageClass   guifg=#ff7b72 ctermfg=210
hi Structure      guifg=#79c0ff ctermfg=117
hi Typedef        guifg=#79c0ff ctermfg=117

hi Special        guifg=#ffa657 ctermfg=215
hi SpecialChar    guifg=#7ee787 ctermfg=114
hi Tag            guifg=#7ee787 ctermfg=114
hi Delimiter      guifg=#c9d1d9 ctermfg=252
hi Debug          guifg=#ffa198 ctermfg=217

hi Underlined     guifg=#79c0ff ctermfg=117     gui=underline cterm=underline
hi Ignore         guifg=#555555 ctermfg=240
hi Error          guifg=#121314 guibg=#f48771   ctermfg=233 ctermbg=210  gui=bold
hi Todo           guifg=#121314 guibg=#ffa657   ctermfg=233 ctermbg=215  gui=bold

" ============================================================
" Diffs
" ============================================================
hi DiffAdd        guifg=#7ee787 guibg=#04260f   ctermfg=114 ctermbg=22
hi DiffChange     guifg=#ffa657 guibg=#5a1e02   ctermfg=215 ctermbg=52
hi DiffDelete     guifg=#ffa198 guibg=#490202   ctermfg=217 ctermbg=52   gui=bold
hi DiffText       guifg=#ffa657 guibg=#5a1e02   ctermfg=215 ctermbg=52   gui=bold

hi diffAdded      guifg=#73c991 ctermfg=114
hi diffRemoved    guifg=#f48771 ctermfg=210
hi diffChanged    guifg=#e5ba7d ctermfg=179
hi diffFile       guifg=#79c0ff ctermfg=117     gui=bold
hi diffLine       guifg=#d2a8ff ctermfg=183     gui=bold

" ============================================================
" Spell checking
" ============================================================
hi SpellBad       guisp=#f48771  gui=undercurl  cterm=underline ctermfg=210
hi SpellCap       guisp=#3994BC  gui=undercurl  cterm=underline ctermfg=31
hi SpellLocal     guisp=#79c0ff  gui=undercurl  cterm=underline ctermfg=117
hi SpellRare      guisp=#e5ba7d  gui=undercurl  cterm=underline ctermfg=179

" ============================================================
" LSP / Diagnostics (Neovim)
" ============================================================
hi DiagnosticError         guifg=#f48771 ctermfg=210
hi DiagnosticWarn          guifg=#e5ba7d ctermfg=179
hi DiagnosticInfo          guifg=#3994BC ctermfg=31
hi DiagnosticHint          guifg=#79c0ff ctermfg=117
hi DiagnosticOk            guifg=#7ee787 ctermfg=114
hi DiagnosticUnderlineError    guisp=#f48771 gui=undercurl cterm=underline
hi DiagnosticUnderlineWarn     guisp=#e5ba7d gui=undercurl cterm=underline
hi DiagnosticUnderlineInfo     guisp=#3994BC gui=undercurl cterm=underline
hi DiagnosticUnderlineHint     guisp=#79c0ff gui=undercurl cterm=underline
hi DiagnosticVirtualTextError  guifg=#f48771 guibg=#3A1D1D ctermfg=210 ctermbg=52
hi DiagnosticVirtualTextWarn   guifg=#e5ba7d guibg=#352A05 ctermfg=179 ctermbg=58
hi DiagnosticVirtualTextInfo   guifg=#3994BC guibg=#1E3A47 ctermfg=31  ctermbg=23
hi DiagnosticVirtualTextHint   guifg=#79c0ff guibg=#1E2A3A ctermfg=117 ctermbg=17

" ============================================================
" Treesitter highlight groups (Neovim 0.8+ only)
" ============================================================
if has('nvim')
  hi! link @comment                Comment
  hi! link @comment.documentation  SpecialComment
  hi! link @keyword                Keyword
  hi! link @keyword.function       Keyword
  hi! link @keyword.operator       Operator
  hi! link @keyword.return         Keyword
  hi! link @function               Function
  hi! link @function.call          Function
  hi! link @function.builtin       Special
  hi! link @method                 Function
  hi! link @method.call            Function
  hi! link @constructor            Function
  hi! link @parameter              Identifier
  hi! link @variable               Identifier
  hi! link @variable.builtin       Special
  hi! link @variable.other         Delimiter
  hi! link @constant               Constant
  hi! link @constant.builtin       Constant
  hi! link @constant.macro         Macro
  hi! link @string                 String
  hi! link @string.escape          SpecialChar
  hi! link @string.special         SpecialChar
  hi! link @character              Character
  hi! link @number                 Number
  hi! link @float                  Float
  hi! link @boolean                Boolean
  hi! link @type                   Type
  hi! link @type.builtin           Type
  hi! link @type.definition        Typedef
  hi! link @attribute              PreProc
  hi! link @field                  Identifier
  hi! link @property               Special
  hi! link @namespace              Directory
  hi! link @include                Include
  hi! link @operator               Operator
  hi! link @punctuation            Delimiter
  hi! link @tag                    Tag
  hi! link @tag.attribute          Special
  hi! link @tag.delimiter          Delimiter
endif

" ============================================================
" Git signs / Gutter markers
" ============================================================
hi GitSignsAdd     guifg=#72C892 guibg=#121314 ctermfg=114 ctermbg=233
hi GitSignsChange  guifg=#e5ba7d guibg=#121314 ctermfg=179 ctermbg=233
hi GitSignsDelete  guifg=#F28772 guibg=#121314 ctermfg=210 ctermbg=233

" ============================================================
" Neovim-specific
" ============================================================
hi FloatBorder    guifg=#2A2B2C guibg=#202122 ctermfg=235 ctermbg=235
hi FloatTitle     guifg=#bfbfbf guibg=#202122 ctermfg=250 ctermbg=235 gui=bold
hi WinBar         guifg=#bfbfbf guibg=#191A1B ctermfg=250 ctermbg=234 gui=bold
hi WinBarNC       guifg=#8C8C8C guibg=#191A1B ctermfg=244 ctermbg=234

" Telescope
hi TelescopeNormal         guibg=#202122
hi TelescopeBorder         guifg=#2A2B2C guibg=#202122
hi TelescopeSelection      guibg=#1e3f52 guifg=#bfbfbf
hi TelescopeSelectionCaret guifg=#3994BC guibg=#202122
hi TelescopeMatching       guifg=#48A0C7 gui=bold

" ============================================================
" coc.nvim
" ============================================================
hi! link CocMenuSel        PmenuSel
hi! link CocPumMenu        Pmenu
hi! link CocPumSearch      IncSearch
hi! link CocPumDetail      NormalFloat
hi! link CocPumVirtualText Comment

hi CocFloating        guifg=#bfbfbf guibg=#202122   ctermfg=250 ctermbg=235
hi! link CocFloatThumb    PmenuThumb
hi! link CocFloatSbar     PmenuSbar
hi CocFloatDividingLine   guifg=#2A2B2C ctermfg=235

hi CocErrorSign         guifg=#f48771 guibg=#121314 ctermfg=210 ctermbg=233
hi CocWarningSign       guifg=#e5ba7d guibg=#121314 ctermfg=179 ctermbg=233
hi CocInfoSign          guifg=#3994BC guibg=#121314 ctermfg=31  ctermbg=233
hi CocHintSign          guifg=#79c0ff guibg=#121314 ctermfg=117 ctermbg=233

hi CocErrorVirtualText  guifg=#f48771 guibg=#3A1D1D ctermfg=210 ctermbg=52  gui=italic cterm=italic
hi CocWarningVirtualText guifg=#e5ba7d guibg=#352A05 ctermfg=179 ctermbg=58  gui=italic cterm=italic
hi CocInfoVirtualText   guifg=#3994BC guibg=#1E3A47 ctermfg=31  ctermbg=23  gui=italic cterm=italic
hi CocHintVirtualText   guifg=#79c0ff guibg=#1E2A3A ctermfg=117 ctermbg=17  gui=italic cterm=italic

hi CocErrorHighlight    guisp=#f48771 gui=undercurl  cterm=underline
hi CocWarningHighlight  guisp=#e5ba7d gui=undercurl  cterm=underline
hi CocInfoHighlight     guisp=#3994BC gui=undercurl  cterm=underline
hi CocHintHighlight     guisp=#79c0ff gui=undercurl  cterm=underline

hi CocDeprecatedHighlight guisp=#8b949e gui=strikethrough cterm=strikethrough
hi CocUnusedHighlight     guifg=#8b949e               ctermfg=245
hi CocCodeLens            guifg=#8C8C8C ctermfg=244   gui=italic cterm=italic

hi CocHighlightText   guibg=#1a3d4f ctermbg=24
hi CocHighlightRead   guibg=#1a3d4f ctermbg=24
hi CocHighlightWrite  guibg=#5a1e02   ctermbg=52

hi CocInlayHint           guifg=#8C8C8C guibg=#191A1B ctermfg=244 ctermbg=234 gui=italic cterm=italic
hi CocInlayHintType       guifg=#79c0ff guibg=#191A1B ctermfg=117 ctermbg=234 gui=italic cterm=italic
hi CocInlayHintParameter  guifg=#ffa657 guibg=#191A1B ctermfg=215 ctermbg=234 gui=italic cterm=italic

hi! link CocSemClass        Type
hi! link CocSemStruct       Type
hi! link CocSemInterface    Type
hi! link CocSemEnum         Type
hi! link CocSemEnumMember   Constant
hi! link CocSemType         Type
hi! link CocSemTypeParameter Type
hi! link CocSemNamespace    Directory
hi! link CocSemFunction     Function
hi! link CocSemMethod       Function
hi! link CocSemProperty     Special
hi! link CocSemVariable     Identifier
hi! link CocSemParameter    Identifier
hi! link CocSemKeyword      Keyword
hi! link CocSemMacro        Macro
hi! link CocSemString       String
hi! link CocSemNumber       Number
hi! link CocSemBoolean      Boolean
hi! link CocSemOperator     Operator
hi! link CocSemComment      Comment
hi CocSemDeprecated         guisp=#8b949e gui=strikethrough cterm=strikethrough
hi CocSemModification       guifg=#e5ba7d ctermfg=179

hi CocListMode     guifg=#bfbfbf guibg=#2A2B2C   ctermfg=250 ctermbg=235  gui=bold
hi CocListPath     guifg=#8C8C8C guibg=#2A2B2C   ctermfg=244 ctermbg=235
hi CocListSearch   guifg=#121314 guibg=#3994BC   ctermfg=233 ctermbg=31   gui=bold
hi! link CocListLine    CursorLine
hi! link CocListSelected PmenuSel

hi CocTreeTitle       guifg=#bfbfbf ctermfg=250 gui=bold
hi CocTreeDescription guifg=#8C8C8C ctermfg=244
hi CocTreeOpenClose   guifg=#555555 ctermfg=240
hi! link CocTreeSelected CursorLine

hi CocGitAddedSign         guifg=#73c991 guibg=#121314 ctermfg=114 ctermbg=233
hi CocGitChangedSign       guifg=#e5ba7d guibg=#121314 ctermfg=179 ctermbg=233
hi CocGitRemovedSign       guifg=#f48771 guibg=#121314 ctermfg=210 ctermbg=233
hi CocGitTopRemovedSign    guifg=#f48771 guibg=#121314 ctermfg=210 ctermbg=233
hi CocGitChangeRemovedSign guifg=#e5ba7d guibg=#121314 ctermfg=179 ctermbg=233
hi CocGitBlame             guifg=#555555 ctermfg=240 gui=italic cterm=italic

hi CocSnippetVisual   guibg=#242526 ctermbg=235

" vim: ft=vim
