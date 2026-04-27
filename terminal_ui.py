#!/usr/bin/env python3
"""
VS Code ライクなターミナル UI エディタ
ファイルブラウザー + テキストエディタ
"""

import os
from pathlib import Path
from typing import Optional
from textual.app import ComposeResult, RenderableType
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Header, Footer, Static, Tree
from textual.widget import Widget
from textual.binding import Binding
from textual.app import App
from rich.syntax import Syntax
from rich.text import Text


class FileTree(Tree):
    """ファイルツリーウィジェット"""

    def render_line(self, key) -> RenderableType:
        """行をレンダリング"""
        node = self.get_node(key)
        if node.data is None:
            return Text()

        prefix = "📁 " if node.data.get("is_dir") else "📄 "
        return Text(prefix + node.label)


class EditorPreview(Static):
    """エディタプレビューウィジェット"""

    DEFAULT_CSS = """
    EditorPreview {
        border: solid $accent;
        overflow: auto;
    }
    """

    def __init__(self):
        super().__init__()
        self.current_file: Optional[Path] = None

    def render(self) -> RenderableType:
        if not self.current_file or not self.current_file.is_file():
            return Text("📭 ファイルを選択してください", style="dim")

        try:
            content = self.current_file.read_text()
            suffix = self.current_file.suffix.lstrip(".")

            lexer_map = {
                "py": "python",
                "js": "javascript",
                "ts": "typescript",
                "tsx": "tsx",
                "jsx": "jsx",
                "json": "json",
                "yaml": "yaml",
                "yml": "yaml",
                "md": "markdown",
                "html": "html",
                "css": "css",
                "sh": "bash",
                "go": "go",
                "rs": "rust",
                "java": "java",
                "cpp": "cpp",
                "c": "c",
            }

            lexer = lexer_map.get(suffix, "text")
            return Syntax(content, lexer, theme="dracula", line_numbers=True)

        except Exception as e:
            return Text(f"❌ エラー: {str(e)}", style="red")


class FileTreeContainer(Vertical):
    """ファイルツリーコンテナ"""

    DEFAULT_CSS = """
    FileTreeContainer {
        width: 30%;
        border: solid $accent;
    }
    """

    def compose(self) -> ComposeResult:
        tree: Tree = FileTree("🏠 Root")
        yield tree


class EditorContainer(Vertical):
    """エディタコンテナ"""

    DEFAULT_CSS = """
    EditorContainer {
        width: 70%;
    }
    """

    def compose(self) -> ComposeResult:
        yield EditorPreview(id="editor-preview")


class TerminalEditor(App):
    """メインアプリケーション"""

    BINDINGS = [
        Binding("q", "quit", "終了"),
        Binding("r", "refresh", "リフレッシュ"),
    ]

    CSS = """
    Screen {
        layout: vertical;
    }

    Horizontal {
        height: 1fr;
    }
    """

    def __init__(self, root_path: str = "."):
        super().__init__()
        self.root_path = Path(root_path).resolve()
        self.selected_file: Optional[Path] = None

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            yield FileTreeContainer(id="file-tree-container")
            yield EditorContainer(id="editor-container")
        yield Footer()

    def on_mount(self) -> None:
        """マウント時に処理"""
        self.title = f"Terminal Editor - {self.root_path.name}"
        self.sub_title = str(self.root_path)
        self._populate_tree()
        self.screen.styles.background = "$surface"

    def _populate_tree(self) -> None:
        """ツリーをポピュレート"""
        tree = self.query_one(Tree)
        self._add_children(tree.root, self.root_path)

    def _add_children(self, parent_node, path: Path) -> None:
        """ディレクトリの子要素を追加"""
        try:
            items = sorted(
                path.iterdir(),
                key=lambda p: (not p.is_dir(), p.name.lower()),
            )

            for item in items:
                if item.name.startswith("."):
                    continue

                is_dir = item.is_dir()
                label = item.name
                node_data = {"path": str(item), "is_dir": is_dir}

                node = parent_node.add(label, data=node_data)

                if is_dir and not item.name.startswith("."):
                    node.add("...")

        except PermissionError:
            pass

    def on_tree_select(self, message: Tree.Selected) -> None:
        """ツリー選択時の処理"""
        node = message.node
        if node.data:
            path = Path(node.data["path"])
            is_dir = node.data.get("is_dir", False)

            if is_dir:
                if len(node.children) == 1 and node.children[0].label == "...":
                    node.children[0].remove()
                    self._add_children(node, path)
            else:
                self.selected_file = path
                preview = self.query_one(EditorPreview)
                preview.current_file = path
                preview.refresh()

    def action_refresh(self) -> None:
        """リフレッシュアクション"""
        tree = self.query_one(Tree)
        tree.clear()
        self._populate_tree()


def main():
    """メイン関数"""
    import sys

    root = sys.argv[1] if len(sys.argv) > 1 else "."
    app = TerminalEditor(root)
    app.run()


if __name__ == "__main__":
    main()
