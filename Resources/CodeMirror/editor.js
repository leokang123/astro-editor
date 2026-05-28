import {history, historyKeymap, standardKeymap} from "@codemirror/commands";
import {markdown} from "@codemirror/lang-markdown";
import {syntaxHighlighting, HighlightStyle, bracketMatching} from "@codemirror/language";
import {EditorState, StateEffect, StateField, Transaction} from "@codemirror/state";
import {
  Decoration,
  drawSelection,
  dropCursor,
  EditorView,
  keymap,
  placeholder,
  scrollPastEnd
} from "@codemirror/view";
import {tags} from "@lezer/highlight";

let currentDocumentID = "";
let suppressChange = false;
let pendingTextChange = 0;
let currentFindQuery = "";

const post = (name, body) => {
  window.webkit?.messageHandlers?.[name]?.postMessage(body);
};

const sourcePositionForScrollTop = () => {
  if (!view) return 1;
  const scrollTop = Math.max(view.scrollDOM.scrollTop - view.documentPadding.top, 0);
  const visibleBlock = view.lineBlockAtHeight(scrollTop);
  const line = view.state.doc.lineAt(visibleBlock.from);
  const lineBlock = view.lineBlockAt(line.from);
  let nextTop = lineBlock.top + lineBlock.height;
  if (line.number < view.state.doc.lines) {
    const nextLine = view.state.doc.line(line.number + 1);
    nextTop = view.lineBlockAt(nextLine.from).top;
  }
  const distance = nextTop - lineBlock.top;
  const progress = distance > 0 ? Math.max(0, Math.min(1, (scrollTop - lineBlock.top) / distance)) : 0;
  return Math.max(line.number + progress, 1);
};

const reportSourcePosition = () => {
  post("sourcePosition", sourcePositionForScrollTop());
};

const postCurrentText = () => {
  pendingTextChange = 0;
  post("textChanged", {
    documentID: currentDocumentID,
    text: view.state.doc.toString()
  });
};

const scheduleTextChange = () => {
  if (pendingTextChange) {
    window.cancelAnimationFrame(pendingTextChange);
  }
  pendingTextChange = window.requestAnimationFrame(postCurrentText);
};

const flushTextChange = () => {
  if (!pendingTextChange) return;
  window.cancelAnimationFrame(pendingTextChange);
  postCurrentText();
};

const searchHighlightEffect = StateEffect.define();

const searchHighlightField = StateField.define({
  create() {
    return Decoration.none;
  },
  update(highlights, transaction) {
    highlights = highlights.map(transaction.changes);
    for (const effect of transaction.effects) {
      if (effect.is(searchHighlightEffect)) {
        highlights = effect.value;
      }
    }
    return highlights;
  },
  provide: field => EditorView.decorations.from(field)
});

const findRanges = query => {
  const text = view.state.doc.toString();
  if (!query || !text) return [];

  const needle = query.toLocaleLowerCase();
  const haystack = text.toLocaleLowerCase();
  const ranges = [];
  let index = haystack.indexOf(needle);
  while (index >= 0) {
    ranges.push({from: index, to: index + query.length});
    index = haystack.indexOf(needle, index + query.length);
  }
  return ranges;
};

const currentMatchIndex = ranges => {
  if (!ranges.length) return 0;
  const selection = view.state.selection.main;
  const index = ranges.findIndex(range => range.from === selection.from && range.to === selection.to);
  if (index >= 0) return index + 1;
  const nextIndex = ranges.findIndex(range => range.from >= selection.head);
  return (nextIndex >= 0 ? nextIndex : 0) + 1;
};

const reportFindStatus = (query, replacementCount = null) => {
  const ranges = findRanges(query);
  post("findStatus", {
    current: query ? currentMatchIndex(ranges) : 0,
    total: query ? ranges.length : 0,
    replacementCount
  });
};

const updateSearchHighlights = (query, replacementCount = null) => {
  const ranges = findRanges(query);
  const decoration = Decoration.mark({class: "cm-searchMatch"});
  view.dispatch({
    effects: searchHighlightEffect.of(Decoration.set(
      ranges.map(range => decoration.range(range.from, range.to)),
      true
    ))
  });
  reportFindStatus(query, replacementCount);
};

const findRange = (query, direction, moveFromSelection) => {
  const ranges = findRanges(query);
  if (!ranges.length) return null;

  const selection = view.state.selection.main;
  if (direction < 0) {
    const start = Math.max((moveFromSelection ? selection.from : selection.to) - 1, 0);
    for (let index = ranges.length - 1; index >= 0; index -= 1) {
      if (ranges[index].from <= start) return ranges[index];
    }
    return ranges[ranges.length - 1];
  }

  const start = moveFromSelection ? selection.to : selection.from;
  return ranges.find(range => range.from >= start) || ranges[0];
};

const selectFindRange = (query, direction, moveFromSelection) => {
  const range = findRange(query, direction, moveFromSelection);
  if (!range) {
    updateSearchHighlights(query);
    return false;
  }
  view.dispatch({
    selection: {anchor: range.from, head: range.to},
    effects: EditorView.scrollIntoView(range.from, {y: "center"})
  });
  updateSearchHighlights(query);
  return true;
};

const selectionMatches = query => {
  const selection = view.state.selection.main;
  if (selection.empty || !query) return false;
  return view.state.doc.sliceString(selection.from, selection.to).toLocaleLowerCase() === query.toLocaleLowerCase();
};

const replaceCurrent = (query, replacement) => {
  if (!query) return false;
  if (!selectionMatches(query) && !selectFindRange(query, 1, true)) {
    updateSearchHighlights(query, 0);
    return false;
  }

  const selection = view.state.selection.main;
  view.dispatch({
    changes: {from: selection.from, to: selection.to, insert: replacement},
    selection: {anchor: selection.from + replacement.length}
  });
  selectFindRange(query, 1, true);
  updateSearchHighlights(query, 1);
  return true;
};

const replaceAll = (query, replacement) => {
  const changes = findRanges(query).map(range => ({from: range.from, to: range.to, insert: replacement}));
  if (!query) return 0;
  if (!changes.length) {
    updateSearchHighlights(query, 0);
    return 0;
  }

  view.dispatch({
    changes,
    selection: {anchor: changes[0].from + replacement.length}
  });
  updateSearchHighlights(query, changes.length);
  return changes.length;
};

const theme = EditorView.theme({
  "&": {
    height: "100%",
    color: "#d7d7d9",
    backgroundColor: "transparent",
    fontSize: "14px"
  },
  ".cm-scroller": {
    overflow: "auto",
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, monospace",
    lineHeight: "1.55",
    cursor: "text"
  },
  ".cm-content": {
    minHeight: "100%",
    padding: "18px 22px",
    caretColor: "#0a84ff",
    color: "#d7d7d9",
    WebkitFontSmoothing: "antialiased"
  },
  "&.cm-focused .cm-selectionBackground, .cm-selectionBackground": {
    backgroundColor: "rgba(10, 132, 255, 0.28) !important"
  },
  ".cm-content ::selection": {
    backgroundColor: "rgba(10, 132, 255, 0.32)",
    color: "#f5f7fa"
  },
  ".cm-cursor": {
    borderLeftColor: "#0a84ff"
  },
  ".cm-line": {
    padding: "0"
  },
  ".cm-gutters": {
    display: "none"
  },
  ".cm-matchingBracket, .cm-nonmatchingBracket": {
    color: "#f5f5f7",
    backgroundColor: "rgba(255, 255, 255, 0.10)"
  },
  ".cm-focused": {
    outline: "none"
  },
  ".cm-placeholder": {
    color: "#7f8790"
  },
  ".cm-searchMatch": {
    backgroundColor: "rgba(255, 214, 102, 0.30)",
    borderRadius: "3px"
  }
});

const markdownHighlightStyle = HighlightStyle.define([
  {tag: tags.heading, color: "#e3e3e6", fontWeight: "700"},
  {tag: tags.link, color: "#9bc7d0"},
  {tag: tags.url, color: "#9bc7d0"},
  {tag: tags.emphasis, color: "#d7d7d9", fontStyle: "italic"},
  {tag: tags.strong, color: "#eeeeef", fontWeight: "700"},
  {tag: tags.monospace, color: "#d5d5d7"},
  {tag: tags.keyword, color: "#cdbfe3"},
  {tag: tags.atom, color: "#dfb99c"},
  {tag: tags.string, color: "#b7d0b4"},
  {tag: tags.number, color: "#dec891"},
  {tag: tags.punctuation, color: "#c9c9cc"},
  {tag: tags.comment, color: "#9a9aa0", fontStyle: "italic"}
]);

const editorExtensions = [
    history(),
    markdown(),
    drawSelection(),
    dropCursor(),
    syntaxHighlighting(markdownHighlightStyle),
    bracketMatching(),
    EditorView.lineWrapping,
    placeholder("Start writing Markdown..."),
    scrollPastEnd(),
    theme,
    searchHighlightField,
    keymap.of([
      ...historyKeymap,
      ...standardKeymap
    ]),
    EditorView.updateListener.of(update => {
      if (update.docChanged && !suppressChange) {
        scheduleTextChange();
      }
      if (update.docChanged && currentFindQuery) {
        window.requestAnimationFrame(() => updateSearchHighlights(currentFindQuery));
      } else if (update.selectionSet && currentFindQuery) {
        reportFindStatus(currentFindQuery);
      }
      if (update.docChanged || update.selectionSet || update.viewportChanged) {
        reportSourcePosition();
      }
    }),
    EditorView.domEventHandlers({
      scroll() {
        reportSourcePosition();
      },
      keydown(event) {
        if (event.metaKey && !event.altKey && !event.ctrlKey && !event.shiftKey && event.key.toLowerCase() === "f") {
          event.preventDefault();
          flushTextChange();
          post("findRequested", null);
          return true;
        }
        if (event.metaKey && !event.altKey && !event.ctrlKey && !event.shiftKey && event.key.toLowerCase() === "e") {
          event.preventDefault();
          flushTextChange();
          post("togglePreview", null);
          return true;
        }
        if (event.metaKey && !event.altKey && !event.ctrlKey && !event.shiftKey && event.key.toLowerCase() === "s") {
          flushTextChange();
          return false;
        }
        if (event.key === "Escape" && !event.metaKey && !event.altKey && !event.ctrlKey && !event.shiftKey) {
          if (view.state.selection.ranges.some(range => !range.empty)) {
            event.preventDefault();
            view.dispatch({selection: {anchor: view.state.selection.main.head}});
            return true;
          }
          return false;
        }
        return false;
      },
      blur() {
        flushTextChange();
        return false;
      },
      paste() {
        post("pasteImages", null);
        return false;
      }
    })
];

const createState = text => EditorState.create({
  doc: text,
  extensions: editorExtensions
});

const view = new EditorView({
  parent: document.getElementById("editor"),
  state: createState("")
});

window.astroPaperEditor = {
  setDocument(payload) {
    const documentID = payload.documentID || "";
    const text = payload.text || "";
    const changedDocument = currentDocumentID !== documentID;
    flushTextChange();
    currentDocumentID = documentID;
    if (changedDocument) {
      suppressChange = true;
      view.setState(createState(text));
      suppressChange = false;
    } else if (view.state.doc.toString() !== text) {
      suppressChange = true;
      view.dispatch({
        changes: {from: 0, to: view.state.doc.length, insert: text},
        selection: {anchor: 0},
        annotations: Transaction.addToHistory.of(false)
      });
      suppressChange = false;
    }
    this.scrollToSourcePosition(payload.sourcePosition || 1);
    post("editorReady", currentDocumentID);
    reportSourcePosition();
  },
  setActive(isActive) {
    flushTextChange();
    if (isActive) {
      view.focus();
    } else {
      view.contentDOM.blur();
    }
  },
  insertText(text) {
    const transaction = view.state.replaceSelection(text || "");
    view.dispatch(transaction);
    view.focus();
  },
  setFindQuery(query) {
    currentFindQuery = query || "";
    if (!currentFindQuery) {
      updateSearchHighlights("");
      return;
    }
    selectFindRange(currentFindQuery, 1, false);
  },
  find(query, direction) {
    currentFindQuery = query || currentFindQuery;
    return selectFindRange(currentFindQuery, direction || 1, true);
  },
  replaceCurrent(query, replacement) {
    currentFindQuery = query || currentFindQuery;
    return replaceCurrent(currentFindQuery, replacement || "");
  },
  replaceAll(query, replacement) {
    currentFindQuery = query || currentFindQuery;
    return replaceAll(currentFindQuery, replacement || "");
  },
  scrollToSourcePosition(position) {
    const targetPosition = Math.max(Number(position) || 1, 1);
    const lineNumber = Math.min(Math.max(Math.floor(targetPosition), 1), view.state.doc.lines);
    const line = view.state.doc.line(lineNumber);
    const block = view.lineBlockAt(line.from);
    let nextTop = block.top + block.height;
    if (line.number < view.state.doc.lines) {
      const nextLine = view.state.doc.line(line.number + 1);
      nextTop = view.lineBlockAt(nextLine.from).top;
    }
    const progress = Math.max(0, Math.min(1, targetPosition - lineNumber));
    view.scrollDOM.scrollTop = Math.max(view.documentPadding.top + block.top + (nextTop - block.top) * progress, 0);
  }
};
