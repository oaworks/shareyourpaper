# README

## Running the site locally

Prerequisites:
- Running from the command line.
- Installing [Node.js](https://nodejs.dev/) and [Node Package Manager](https://www.npmjs.com/) or `npm`.

1. Clone this repository by typing in your terminal: `git clone https://github.com/oaworks/shareyourpaper.git`
2. Change to its newly created directory: `cd shareyourpaper/`
3. Run `npm install`
4. Run the server by entering `API_ENDPOINT=https://beta.oa.works npm run dev`
   - Use `https://api.oa.works` for the live API. **If you leave `API_ENDPOINT` out, the live API is used, so test deposits will go to production.**
   - The site rebuilds when editing files or switching branches.
5. Direct your web browser to `http://localhost:8080/`
   - DOI paths only work on Cloudflare; use `http://localhost:8080/?doi=10.1016/j.cplett.2012.10.045` instead of `http://localhost:8080/10.1016/j.cplett.2012.10.045`
6. Always create a branch off `dev` when making commits

## Viewing the various servers

Both are deployed on Cloudflare Pages.

| `dev` (https://dev.shareyourpaper.org) | `main` (https://shareyourpaper.org) |
|---|---|
| Uses the `beta` API | Uses the live API |
