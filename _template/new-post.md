<%*
const title = await tp.system.prompt("Post title");
const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const date = tp.date.now("YYYY-MM-DD");
const datetime = tp.date.now("YYYY-MM-DDTHH:mm:ssZ");
const folder = `content/posts/${date}-${slug}`;
await app.vault.createFolder(folder);
const content = `+++\ndate = '${datetime}'\ndraft = false\ntitle = '${title}'\ntags = []\n\n[params.cover]\n  image = "banner.png"\n  alt = "${title}"\n  relative = true\n+++\n\n`;
await app.vault.create(`${folder}/index.md`, content);
await app.workspace.openLinkText(`${folder}/index.md`, "");
%>

