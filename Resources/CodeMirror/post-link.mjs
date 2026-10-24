import {slug as githubSlug} from "github-slugger";
import kebabcase from "lodash.kebabcase";
import slugify from "slugify";

export function postLinkPath({relativePath, slug}) {
  // Match Astro's glob loader and the starter's getPath / slugifyStr helpers.
  const parts = relativePath.replace(/\.md$/, "").split("/");
  const id = slug || parts.map(part => githubSlug(part)).join("/").replace(/\/index$/, "");
  const directories = parts.slice(0, -1).filter(part => !part.startsWith("_")).map(part => {
    const normalized = part.normalize("NFC");
    return /[^\x00-\x7F]/.test(normalized)
      ? kebabcase(normalized).normalize("NFC")
      : slugify(normalized, {lower: true});
  });
  return ["", "posts", ...directories, id.split("/").at(-1).normalize("NFC")]
    .map(segment => Array.from(segment, char => /[\p{L}\p{N}\p{M}]/u.test(char)
      ? char
      : encodeURIComponent(char).replace(/[!'()*]/g, punctuation =>
        `%${punctuation.charCodeAt(0).toString(16).toUpperCase()}`)).join(""))
    .join("/");
}

export function postLinkMarkdown(document) {
  const path = postLinkPath(document);
  const label = document.title.replace(/[\\`*_[\]<>]/g, "\\$&").replace(/[\r\n]+/g, " ");
  return `[${label}](${path})`;
}
