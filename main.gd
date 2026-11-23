
extends Control

const LIGHT = Color("#EEE2CC")
const DARK = Color("#8A9A78")
const SELECTED = Color("#E5C56B")
const HIGHLIGHT = Color("#B8C98C")

var board = []
var squares = []
var selected = Vector2i(-1, -1)
var turn = "w"
var game_over = false
var status_label: Label
var history = []
var en_passant = Vector2i(-1, -1)
var castle_rights = {"wK": true, "wQ": true, "bK": true, "bQ": true}

func _ready():
    build_interface()
    new_game()

func build_interface():
    var background = ColorRect.new()
    background.color = Color("#19232B")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var layout = VBoxContainer.new()
    layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layout.add_theme_constant_override("separation", 18)
    add_child(layout)

    var spacer = Control.new()
    spacer.custom_minimum_size.y = 35
    layout.add_child(spacer)

    var title = Label.new()
    title.text = "CHESS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 46)
    title.add_theme_color_override("font_color", Color("#E9D6B0"))
    layout.add_child(title)

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 25)
    layout.add_child(status_label)

    var center = CenterContainer.new()
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layout.add_child(center)

    var grid = GridContainer.new()
    grid.columns = 8
    grid.add_theme_constant_override("h_separation", 0)
    grid.add_theme_constant_override("v_separation", 0)
    center.add_child(grid)

    for y in range(8):
        var row = []
        for x in range(8):
            var button = Button.new()
            button.custom_minimum_size = Vector2(85, 85)
            button.add_theme_font_size_override("font_size", 43)
            button.focus_mode = Control.FOCUS_NONE
            button.pressed.connect(on_square.bind(x, y))
            grid.add_child(button)
            row.append(button)
        squares.append(row)

    var controls = HBoxContainer.new()
    controls.alignment = BoxContainer.ALIGNMENT_CENTER
    controls.add_theme_constant_override("separation", 20)
    layout.add_child(controls)

    var restart = Button.new()
    restart.text = "New Game"
    restart.custom_minimum_size = Vector2(190, 65)
    restart.pressed.connect(new_game)
    controls.add_child(restart)

    var undo = Button.new()
    undo.text = "Undo"
    undo.custom_minimum_size = Vector2(150, 65)
    undo.pressed.connect(undo_move)
    controls.add_child(undo)

    var bottom = Control.new()
    bottom.custom_minimum_size.y = 45
    layout.add_child(bottom)

func new_game():
    board = [
        ["br","bn","bb","bq","bk","bb","bn","br"],
        ["bp","bp","bp","bp","bp","bp","bp","bp"],
        ["","","","","","","",""],
        ["","","","","","","",""],
        ["","","","","","","",""],
        ["","","","","","","",""],
        ["wp","wp","wp","wp","wp","wp","wp","wp"],
        ["wr","wn","wb","wq","wk","wb","wn","wr"]
    ]
    turn = "w"
    selected = Vector2i(-1, -1)
    en_passant = Vector2i(-1, -1)
    castle_rights = {"wK": true, "wQ": true, "bK": true, "bQ": true}
    history.clear()
    game_over = false
    refresh()

func inside(x, y):
    return x >= 0 and x < 8 and y >= 0 and y < 8

func enemy(piece, color):
    return piece != "" and piece.substr(0, 1) != color

func piece_moves(x, y, attacks_only = false):
    var result = []
    var piece = board[y][x]
    if piece == "":
        return result

    var color = piece.substr(0, 1)
    var kind = piece.substr(1, 1)
    var directions = []

    if kind == "p":
        var direction = -1 if color == "w" else 1
        for dx in [-1, 1]:
            var nx = x + dx
            var ny = y + direction
            if inside(nx, ny):
                if attacks_only or enemy(board[ny][nx], color):
                    result.append(Vector2i(nx, ny))
                elif Vector2i(nx, ny) == en_passant:
                    result.append(Vector2i(nx, ny))
        if not attacks_only:
            var ny = y + direction
            if inside(x, ny) and board[ny][x] == "":
                result.append(Vector2i(x, ny))
                var start = 6 if color == "w" else 1
                if y == start and board[y + direction * 2][x] == "":
                    result.append(Vector2i(x, y + direction * 2))
        return result

    if kind == "n":
        directions = [
            Vector2i(1, 2), Vector2i(2, 1),
            Vector2i(-1, 2), Vector2i(-2, 1),
            Vector2i(1, -2), Vector2i(2, -1),
            Vector2i(-1, -2), Vector2i(-2, -1)
        ]
    elif kind == "k":
        directions = [
            Vector2i(1, 0), Vector2i(-1, 0),
            Vector2i(0, 1), Vector2i(0, -1),
            Vector2i(1, 1), Vector2i(-1, 1),
            Vector2i(1, -1), Vector2i(-1, -1)
        ]
    else:
        if kind == "r" or kind == "q":
            directions.append_array([
                Vector2i(1, 0), Vector2i(-1, 0),
                Vector2i(0, 1), Vector2i(0, -1)
            ])
        if kind == "b" or kind == "q":
            directions.append_array([
                Vector2i(1, 1), Vector2i(-1, 1),
                Vector2i(1, -1), Vector2i(-1, -1)
            ])

    for d in directions:
        var nx = x + d.x
        var ny = y + d.y
        while inside(nx, ny):
            var target = board[ny][nx]
            if target == "":
                result.append(Vector2i(nx, ny))
            else:
                if enemy(target, color):
                    result.append(Vector2i(nx, ny))
                break
            if kind == "n" or kind == "k":
                break
            nx += d.x
            ny += d.y

    if kind == "k" and not attacks_only:
        var home = 7 if color == "w" else 0
        if y == home and x == 4 and not in_check(color):
            var opponent = "b" if color == "w" else "w"
            if castle_rights[color + "K"]:
                if board[home][5] == "" and board[home][6] == "" and board[home][7] == color + "r":
                    if not attacked(5, home, opponent) and not attacked(6, home, opponent):
                        result.append(Vector2i(6, home))
            if castle_rights[color + "Q"]:
                if board[home][1] == "" and board[home][2] == "" and board[home][3] == "" and board[home][0] == color + "r":
                    if not attacked(3, home, opponent) and not attacked(2, home, opponent):
                        result.append(Vector2i(2, home))

    return result

func attacked(x, y, by_color):
    for py in range(8):
        for px in range(8):
            var piece = board[py][px]
            if piece != "" and piece.substr(0, 1) == by_color:
                if Vector2i(x, y) in piece_moves(px, py, true):
                    return true
    return false

func in_check(color):
    for y in range(8):
        for x in range(8):
            if board[y][x] == color + "k":
                var opponent = "b" if color == "w" else "w"
                return attacked(x, y, opponent)
    return true

func legal_moves(x, y):
    var piece = board[y][x]
    if piece == "":
        return []
    var color = piece.substr(0, 1)
    var result = []
    for target in piece_moves(x, y):
        if board[target.y][target.x] == "wk" or board[target.y][target.x] == "bk":
            continue
        var old_board = board.duplicate(true)
        apply_board_move(Vector2i(x, y), target)
        if not in_check(color):
            result.append(target)
        board = old_board
    return result

func apply_board_move(from, to):
    var piece = board[from.y][from.x]
    if piece.substr(1, 1) == "p" and to.x != from.x and board[to.y][to.x] == "":
        board[from.y][to.x] = ""
    if piece.substr(1, 1) == "k" and abs(to.x - from.x) == 2:
        if to.x == 6:
            board[from.y][5] = board[from.y][7]
            board[from.y][7] = ""
        else:
            board[from.y][3] = board[from.y][0]
            board[from.y][0] = ""
    board[to.y][to.x] = piece
    board[from.y][from.x] = ""
    if piece.substr(1, 1) == "p" and (to.y == 0 or to.y == 7):
        board[to.y][to.x] = piece.substr(0, 1) + "q"

func on_square(x, y):
    if game_over:
        return
    var target = Vector2i(x, y)
    var piece = board[y][x]

    if selected.x >= 0:
        if target in legal_moves(selected.x, selected.y):
            make_move(selected, target)
            return

    if piece != "" and piece.substr(0, 1) == turn:
        selected = target
    else:
        selected = Vector2i(-1, -1)
    refresh()

func make_move(from, to):
    history.append({
        "board": board.duplicate(true),
        "turn": turn,
        "ep": en_passant,
        "castle": castle_rights.duplicate()
    })

    var piece = board[from.y][from.x]
    var captured = board[to.y][to.x]
    if piece == "wk":
        castle_rights["wK"] = false
        castle_rights["wQ"] = false
    if piece == "bk":
        castle_rights["bK"] = false
        castle_rights["bQ"] = false

    if piece == "wr" and from == Vector2i(0, 7):
        castle_rights["wQ"] = false
    if piece == "wr" and from == Vector2i(7, 7):
        castle_rights["wK"] = false
    if piece == "br" and from == Vector2i(0, 0):
        castle_rights["bQ"] = false
    if piece == "br" and from == Vector2i(7, 0):
        castle_rights["bK"] = false

    if captured == "wr" and to == Vector2i(0, 7):
        castle_rights["wQ"] = false
    if captured == "wr" and to == Vector2i(7, 7):
        castle_rights["wK"] = false
    if captured == "br" and to == Vector2i(0, 0):
        castle_rights["bQ"] = false
    if captured == "br" and to == Vector2i(7, 0):
        castle_rights["bK"] = false

    apply_board_move(from, to)
    en_passant = Vector2i(-1, -1)
    if piece.substr(1, 1) == "p" and abs(to.y - from.y) == 2:
        en_passant = Vector2i(from.x, (from.y + to.y) / 2)

    turn = "b" if turn == "w" else "w"
    selected = Vector2i(-1, -1)
    refresh()

func has_legal_moves(color):
    for y in range(8):
        for x in range(8):
            var piece = board[y][x]
            if piece != "" and piece.substr(0, 1) == color:
                if not legal_moves(x, y).is_empty():
                    return true
    return false

func undo_move():
    if history.is_empty():
        return
    var previous = history.pop_back()
    board = previous["board"]
    turn = previous["turn"]
    en_passant = previous["ep"]
    castle_rights = previous["castle"]
    selected = Vector2i(-1, -1)
    game_over = false
    refresh()

func refresh():
    var player = "White" if turn == "w" else "Black"
    if not has_legal_moves(turn):
        game_over = true
        if in_check(turn):
            status_label.text = "Checkmate! " + ("Black" if turn == "w" else "White") + " wins"
        else:
            status_label.text = "Stalemate — Draw"
    elif in_check(turn):
        status_label.text = player + " is in check!"
    else:
        status_label.text = player + " to move"

    var moves = []
    if selected.x >= 0:
        moves = legal_moves(selected.x, selected.y)

    var symbols = {
        "wk":"♔", "wq":"♕", "wr":"♖",
        "wb":"♗", "wn":"♘", "wp":"♙",
        "bk":"♚", "bq":"♛", "br":"♜",
        "bb":"♝", "bn":"♞", "bp":"♟"
    }

    for y in range(8):
        for x in range(8):
            var button = squares[y][x]
            var position = Vector2i(x, y)
            var color = LIGHT if (x + y) % 2 == 0 else DARK
            if position == selected:
                color = SELECTED
            elif position in moves:
                color = HIGHLIGHT

            var style = StyleBoxFlat.new()
            style.bg_color = color
            button.add_theme_stylebox_override("normal", style)
            button.add_theme_stylebox_override("hover", style)
            button.add_theme_stylebox_override("pressed", style)

            var piece = board[y][x]
            button.text = symbols.get(piece, "")
            if piece.begins_with("w"):
                button.add_theme_color_override("font_color", Color("#FFFFFF"))
            else:
                button.add_theme_color_override("font_color", Color("#202A32"))
