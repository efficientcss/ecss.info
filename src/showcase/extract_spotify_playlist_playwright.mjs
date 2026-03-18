#!/usr/bin/env node

import { writeFile } from "node:fs/promises";
import process from "node:process";

const usage = () => {
	console.error("Usage: node showcase/extract_spotify_playlist_playwright.mjs <playlist-url> [output-xml]");
	process.exit(1);
};

if (process.argv.length < 3 || process.argv.length > 4) {
	usage();
}

let chromium;
try {
	({ chromium } = await import("playwright"));
} catch (error) {
	console.error("playwright is required. Install it with: npm install -D playwright");
	process.exit(1);
}

const absoluteSpotifyUrl = (value) => {
	if (!value) return "";
	if (value.startsWith("http://") || value.startsWith("https://")) return value;
	if (value.startsWith("/")) return `https://open.spotify.com${value}`;
	return value;
};

const toLargeSpotifyCover = (value) => {
	if (!value) return "";
	return value
		.replace("ab67616d00004851", "ab67616d0000b273")
		.replace("ab67616d00001e02", "ab67616d0000b273");
};

const xmlEscape = (value) =>
	String(value)
		.replaceAll("&", "&amp;")
		.replaceAll("<", "&lt;")
		.replaceAll(">", "&gt;")
		.replaceAll('"', "&quot;")
		.replaceAll("'", "&apos;");

const toXml = (playlist) => {
	const lines = [
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
		"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
		"<plist version=\"1.0\">",
		"<dict>",
		"\t<key>Major Version</key><integer>1</integer>",
		"\t<key>Minor Version</key><integer>1</integer>",
		"\t<key>Application Version</key><string>Spotify Playwright Import</string>",
		"\t<key>Features</key><integer>1</integer>",
		`\t<key>Playlist ID</key><string>${xmlEscape(playlist.id || "")}</string>`,
		`\t<key>Playlist Name</key><string>${xmlEscape(playlist.name || "Spotify Playlist")}</string>`,
		`\t<key>Playlist URL</key><string>${xmlEscape(playlist.url || "")}</string>`,
		"\t<key>Tracks</key>",
		"\t<dict>",
	];

	playlist.tracks.forEach((track, index) => {
		lines.push(`\t\t<key>${index + 1}</key>`);
		lines.push("\t\t<dict>");
		lines.push(`\t\t\t<key>Name</key><string>${xmlEscape(track.name || "")}</string>`);
		lines.push(`\t\t\t<key>Artist</key><string>${xmlEscape(track.artist || "")}</string>`);
		lines.push(`\t\t\t<key>Album</key><string>${xmlEscape(track.album || "")}</string>`);
		if (track.year && /^\d{4}$/.test(track.year)) {
			lines.push(`\t\t\t<key>Year</key><integer>${track.year}</integer>`);
		}
		if (track.location) {
			lines.push(`\t\t\t<key>Location</key><string>${xmlEscape(track.location)}</string>`);
		}
		if (track.cover_url) {
			lines.push(`\t\t\t<key>Cover URL</key><string>${xmlEscape(track.cover_url)}</string>`);
		}
		if (track.spotify_track_url) {
			lines.push(`\t\t\t<key>Spotify Track URL</key><string>${xmlEscape(track.spotify_track_url)}</string>`);
		}
		if (track.spotify_album_url) {
			lines.push(`\t\t\t<key>Spotify Album URL</key><string>${xmlEscape(track.spotify_album_url)}</string>`);
		}
		if (track.spotify_artist_url) {
			lines.push(`\t\t\t<key>Spotify Artist URL</key><string>${xmlEscape(track.spotify_artist_url)}</string>`);
		}
		lines.push("\t\t</dict>");
	});

	lines.push("\t</dict>");
	lines.push("</dict>");
	lines.push("</plist>");

	return `${lines.join("\n")}\n`;
};

const playlistUrl = process.argv[2];
const outputPath = process.argv[3] || "showcase/spotify-playlist.xml";
const browser = await chromium.launch({
	headless: true,
});
const page = await browser.newPage();

const collectSnapshot = async () =>
	page.evaluate(() => {
		const text = (node) => node?.textContent?.trim() || "";
		const meta = (selector) => document.querySelector(selector)?.getAttribute("content") || "";
		const playlistUrlFromMeta = meta('meta[property="og:url"]') || location.href;
		const playlistName = meta('meta[property="og:title"]') || document.title.replace(/\s*-\s*playlist.*$/i, "").trim();
		const playlistIdMatch = playlistUrlFromMeta.match(/\/playlist\/([A-Za-z0-9]+)/);
		const expectedCountMatch = (meta('meta[property="og:description"]') || meta('meta[name="description"]') || "").match(/(\d+)\s+items?/i);
		const expectedCount = expectedCountMatch ? Number.parseInt(expectedCountMatch[1], 10) : 0;
		const rows = Array.from(document.querySelectorAll('[data-testid="tracklist-row"]'));
		const tracks = rows.map((row) => {
			const trackCell = row.querySelector('[aria-colindex="2"]') || row;
			const albumCell = row.querySelector('[aria-colindex="3"]') || row;
			const dateCell = row.querySelector('[aria-colindex="5"]') || null;
			const trackLink = trackCell.querySelector('a[data-testid="internal-track-link"], a[href^="/track/"]');
			const artistLinks = Array.from(trackCell.querySelectorAll('a[href^="/artist/"]'));
			const albumLink = albumCell.querySelector('a[href^="/album/"]');
			const cover = row.querySelector('img[src*="scdn.co"], img[src*="spotifycdn"]');
			const addedOrYear = text(dateCell);
			const yearMatch = addedOrYear.match(/\b(19|20)\d{2}\b/);

			return {
				name: text(trackLink),
				artist: artistLinks.map((link) => text(link)).filter(Boolean).join(", "),
				album: text(albumLink),
				year: yearMatch ? yearMatch[0] : "",
				location: cover?.getAttribute("src") || "",
				cover_url: cover?.getAttribute("src") || "",
				spotify_track_url: trackLink?.getAttribute("href") || "",
				spotify_album_url: albumLink?.getAttribute("href") || "",
				spotify_artist_url: artistLinks[0]?.getAttribute("href") || "",
			};
		}).filter((track) => track.name && track.spotify_track_url);

		return {
			id: playlistIdMatch?.[1] || "",
			name: playlistName,
			url: playlistUrlFromMeta,
			expectedCount,
			tracks,
		};
	});

const mergeTracks = (existing, incoming) => {
	for (const track of incoming) {
		const key = absoluteSpotifyUrl(track.spotify_track_url) || `${track.artist}|${track.album}|${track.name}`;
		if (!key) continue;
		if (existing.has(key)) continue;
		existing.set(key, {
			...track,
			location: toLargeSpotifyCover(track.location || ""),
			cover_url: toLargeSpotifyCover(track.cover_url || track.location || ""),
			spotify_track_url: absoluteSpotifyUrl(track.spotify_track_url),
			spotify_album_url: absoluteSpotifyUrl(track.spotify_album_url),
			spotify_artist_url: absoluteSpotifyUrl(track.spotify_artist_url),
		});
	}
};

const advanceTracklist = async () =>
	page.evaluate(() => {
		const row = document.querySelector('[data-testid="tracklist-row"]');
		const findScrollableAncestor = (node) => {
			let current = node;
			while (current && current !== document.body) {
				if (!(current instanceof HTMLElement)) {
					current = current.parentElement;
					continue;
				}
				const style = window.getComputedStyle(current);
				const overflowY = style.overflowY;
				if ((overflowY === "auto" || overflowY === "scroll") && current.scrollHeight > current.clientHeight + 20) {
					return current;
				}
				current = current.parentElement;
			}
			return document.scrollingElement || document.documentElement;
		};

		const scroller = findScrollableAncestor(row || document.body);
		const previousTop = scroller.scrollTop;
		const increment = Math.max(Math.floor(scroller.clientHeight * 0.9), 600);
		scroller.scrollTop = Math.min(scroller.scrollTop + increment, scroller.scrollHeight);

		if (scroller.scrollTop === previousTop) {
			const rows = Array.from(document.querySelectorAll('[data-testid="tracklist-row"]'));
			rows.at(-1)?.scrollIntoView({ block: "end" });
		}

		return {
			tagName: scroller.tagName,
			scrollTop: scroller.scrollTop,
			scrollHeight: scroller.scrollHeight,
			clientHeight: scroller.clientHeight,
		};
	});

try {
	await page.goto(playlistUrl, {
		waitUntil: "domcontentloaded",
		timeout: 45000,
	});

	await page.waitForSelector('meta[property="og:description"], [data-testid="tracklist-row"], [data-testid="tracklist-row-placeholder"]', {
		state: "attached",
		timeout: 15000,
	});
	await page.waitForTimeout(1500);

	const trackMap = new Map();
	let playlistMeta = {
		id: "",
		name: "",
		url: playlistUrl,
		expectedCount: 0,
	};
	let stagnantPasses = 0;
	let previousCount = 0;

	for (let attempt = 0; attempt < 80; attempt += 1) {
		const snapshot = await collectSnapshot();
		playlistMeta = {
			...playlistMeta,
			id: snapshot.id || playlistMeta.id,
			name: snapshot.name || playlistMeta.name,
			url: snapshot.url || playlistMeta.url,
			expectedCount: snapshot.expectedCount || playlistMeta.expectedCount,
		};
		mergeTracks(trackMap, snapshot.tracks);

		if (trackMap.size === previousCount) {
			stagnantPasses += 1;
		} else {
			stagnantPasses = 0;
			previousCount = trackMap.size;
		}

		if (playlistMeta.expectedCount && trackMap.size >= playlistMeta.expectedCount) {
			break;
		}

		if (stagnantPasses >= 5) {
			break;
		}

		if (!playlistMeta.expectedCount && stagnantPasses >= 2) {
			break;
		}

		await advanceTracklist();
		await page.waitForTimeout(600);
	}

	const playlist = {
		id: playlistMeta.id,
		name: playlistMeta.name,
		url: playlistMeta.url,
		tracks: Array.from(trackMap.values()),
	};

	await writeFile(outputPath, toXml(playlist), "utf8");
	console.log(`Wrote ${outputPath} (${playlist.tracks.length} tracks)`);
} finally {
	await browser.close();
}
