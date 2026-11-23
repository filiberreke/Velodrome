const releaseDownloads = document.querySelectorAll("[data-release-asset]");
const releaseSource = document.querySelector("[data-release-api]");

async function showReleaseDownloads() {
  try {
    const response = await fetch(releaseSource.dataset.releaseApi);
    if (!response.ok) return;
    const release = await response.json();
    const uploaded = new Set(release.assets.filter((asset) => asset.state === "uploaded").map((asset) => asset.name));
    for (const link of releaseDownloads) {
      link.hidden = false;
    }
  } catch {
    // The GitHub Releases index remains available when the API cannot be reached.
  }
}

if (releaseSource) showReleaseDownloads();
