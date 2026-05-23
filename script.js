const warningCopy = {
  culture: {
    title: "No meme, no bid.",
    body: "Monero owns the simple meme: private by default. Zcash explained. The market yawned."
  },
  liquidity: {
    title: "Liquidity hates messy wrappers.",
    body: "Optional privacy, governance drama, old holders, policy heat. That is not a clean rotation. That is exit liquidity anxiety."
  },
  attention: {
    title: "Attention already left.",
    body: "ZEC got a decade. Monero kept the privacy brand. ZCRASH gets one job: make the failure visible enough to trade."
  }
};

const sourceStack = [
  {
    label: "the toggle",
    claim: "privacy cannot be the product and the toggle.",
    detail: "transparent addresses are in the docs. the bear case does not need to be invented. it is sitting in the product surface.",
    url: "https://zcash.readthedocs.io/en/latest/rtd_pages/addresses.html"
  },
  {
    label: "the rupture",
    claim: "eventually the wrapper started fighting itself.",
    detail: "reported full ECC team resignation after a governance dispute. this is how a serious thesis starts leaking confidence.",
    url: "https://www.theblock.co/post/384737/zcash-developers-form-new-company/"
  },
  {
    label: "the paperwork",
    claim: "private money got stuck in nonprofit machinery.",
    detail: "maybe the process was legally rational. the market does not care. it prices the smell.",
    url: "https://weareallzashi.org/statement.html"
  },
  {
    label: "the crowd",
    claim: "the crowd started saying the quiet part out loud.",
    detail: "fomo posts, influencer blame, crash jokes. not exactly the texture of organic inevitability.",
    url: "https://www.reddit.com/r/CryptoCurrency/comments/1pbcg87/zcash_crashes_35_in_just_7_days/"
  }
];

const sourceStackDelay = 4200;
const sourceCard = document.querySelector(".source-stack");
const sourceLabel = document.querySelector("#source-label");
const sourceCount = document.querySelector("#source-count");
const sourceClaim = document.querySelector("#source-claim");
const sourceDetail = document.querySelector("#source-detail");
const sourceLink = document.querySelector("#source-link");

let sourceIndex = 0;

function renderSource(index) {
  const source = sourceStack[index];
  const count = String(index + 1).padStart(2, "0");
  const total = String(sourceStack.length).padStart(2, "0");

  if (!sourceLabel || !sourceCount || !sourceClaim || !sourceDetail || !sourceLink) {
    return;
  }

  sourceLabel.textContent = source.label;
  sourceCount.textContent = `${count} / ${total}`;
  sourceClaim.textContent = source.claim;
  sourceDetail.textContent = source.detail;
  sourceLink.href = source.url;
  sourceLink.textContent = "receipt";

  sourceCard.classList.remove("is-swapping");
  window.requestAnimationFrame(() => {
    sourceCard.classList.add("is-swapping");
  });
}

if (sourceCard) {
  renderSource(sourceIndex);

  window.setInterval(() => {
    sourceIndex = (sourceIndex + 1) % sourceStack.length;
    renderSource(sourceIndex);
  }, sourceStackDelay);
}

const tabs = document.querySelectorAll(".warning-tab");
const warningContent = document.querySelector("#warning-content");

tabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    const selected = warningCopy[tab.dataset.tab];

    tabs.forEach((item) => item.classList.remove("active"));
    tab.classList.add("active");

    warningContent.animate(
      [
        { opacity: 0, transform: "translateY(8px)" },
        { opacity: 1, transform: "translateY(0)" }
      ],
      {
        duration: 220,
        easing: "ease-out"
      }
    );

    warningContent.innerHTML = `
      <h3>${selected.title}</h3>
      <p>${selected.body}</p>
    `;
  });
});

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
      }
    });
  },
  { threshold: 0.16 }
);

document.querySelectorAll("section, .market-strip, .terminal-panel").forEach((section) => {
  section.classList.add("reveal");
  observer.observe(section);
});

const jackpot = {
  tokenAddress: "0x1a043eAeC3f5A33388DE42862C45dF2642000000",
  contractAddress: "",
  chainId: 999,
  chainIdHex: "0x3e7",
  decimals: 18,
  provider: null,
  signer: null,
  account: null,
  contract: null,
  token: null,
  state: null,
  allowance: null,
  txPending: false,
  refreshPending: false
};

const jackpotAbi = [
  "function leader() view returns (address)",
  "function lastWinner() view returns (address)",
  "function pot() view returns (uint256)",
  "function entryAmount() view returns (uint256)",
  "function jackpotDuration() view returns (uint256)",
  "function endsAt() view returns (uint256)",
  "function enter()",
  "function claimPrize()"
];

const tokenAbi = [
  "function allowance(address owner,address spender) view returns (uint256)",
  "function approve(address spender,uint256 amount) returns (bool)"
];

const jackpotEls = {
  clock: document.querySelector("#jackpot-clock"),
  title: document.querySelector("#jackpot-title"),
  status: document.querySelector("#jackpot-status"),
  entry: document.querySelector("#jackpot-entry"),
  pot: document.querySelector("#jackpot-pot"),
  leader: document.querySelector("#jackpot-leader"),
  wallet: document.querySelector("#jackpot-wallet"),
  allowance: document.querySelector("#jackpot-allowance"),
  message: document.querySelector("#jackpot-message"),
  connect: document.querySelector("#jackpot-connect"),
  approve: document.querySelector("#jackpot-approve"),
  enter: document.querySelector("#jackpot-enter"),
  claim: document.querySelector("#jackpot-claim")
};

function shortAddress(address) {
  if (!address || address === "0x0000000000000000000000000000000000000000") {
    return "none";
  }

  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function formatToken(amount) {
  if (!window.ethers || !amount) {
    return "--";
  }

  const value = window.ethers.utils.formatUnits(amount, jackpot.decimals);
  return Number(value).toLocaleString("en-US", {
    maximumFractionDigits: 4
  });
}

function setJackpotMessage(message) {
  if (jackpotEls.message) {
    jackpotEls.message.textContent = message;
  }
}

function setJackpotButtons() {
  const connected = Boolean(jackpot.account && jackpot.contract && jackpot.state);
  const expired = connected && jackpot.state.endsAt.toNumber() <= Math.floor(Date.now() / 1000);
  const hasPot = connected && !jackpot.state.pot.isZero();
  const isLeader = connected && jackpot.state.leader.toLowerCase() === jackpot.account.toLowerCase();
  const hasClaim = connected && expired && hasPot && isLeader;
  const hasAllowance = connected && jackpot.allowance?.gte(jackpot.state.entryAmount);
  const locked = jackpot.txPending;
  const missingContract = !jackpot.contractAddress;

  jackpotEls.connect.disabled = Boolean(jackpot.account) || locked || missingContract;
  jackpotEls.approve.disabled = locked || !connected || expired || hasAllowance;
  jackpotEls.enter.disabled = locked || !connected || (expired && hasPot) || !hasAllowance;
  jackpotEls.claim.disabled = locked || !hasClaim;
}

function renderJackpotState() {
  if (!jackpotEls.clock) {
    return;
  }

  if (!jackpot.state) {
    jackpotEls.clock.textContent = "--:--";
    setJackpotButtons();
    return;
  }

  const now = Math.floor(Date.now() / 1000);
  const secondsLeft = Math.max(0, jackpot.state.endsAt.toNumber() - now);
  const minutes = String(Math.floor(secondsLeft / 60)).padStart(2, "0");
  const seconds = String(secondsLeft % 60).padStart(2, "0");

  jackpotEls.clock.textContent = `${minutes}:${seconds}`;
  jackpotEls.title.textContent = "Jackpot";
  jackpotEls.entry.textContent = `${formatToken(jackpot.state.entryAmount)} ZCRASH`;
  jackpotEls.pot.textContent = `${formatToken(jackpot.state.pot)} ZCRASH`;
  jackpotEls.leader.textContent = shortAddress(jackpot.state.leader);
  jackpotEls.wallet.textContent = jackpot.account ? shortAddress(jackpot.account) : "not connected";
  jackpotEls.allowance.textContent = jackpot.allowance ? `${formatToken(jackpot.allowance)} ZCRASH` : "--";

  if (secondsLeft === 0 && jackpot.state.pot.isZero()) {
    jackpotEls.status.textContent = "empty expired";
  } else if (secondsLeft === 0 && jackpot.state.leader.toLowerCase() === jackpot.account?.toLowerCase()) {
    jackpotEls.status.textContent = "claimable";
  } else if (secondsLeft === 0) {
    jackpotEls.status.textContent = "waiting winner";
  } else {
    jackpotEls.status.textContent = "live";
  }

  setJackpotButtons();
}

async function ensureHyperEvm() {
  const chainId = await window.ethereum.request({ method: "eth_chainId" });

  if (chainId === jackpot.chainIdHex) {
    return;
  }

  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: jackpot.chainIdHex }]
    });
  } catch (error) {
    if (error.code !== 4902) {
      throw error;
    }

    await window.ethereum.request({
      method: "wallet_addEthereumChain",
      params: [
        {
          chainId: jackpot.chainIdHex,
          chainName: "HyperEVM",
          nativeCurrency: {
            name: "HYPE",
            symbol: "HYPE",
            decimals: 18
          },
          rpcUrls: ["https://rpc.hyperliquid.xyz/evm"],
          blockExplorerUrls: ["https://hyperevmscan.io"]
        }
      ]
    });
  }
}

async function refreshJackpot() {
  if (!jackpot.contract || !jackpot.account) {
    renderJackpotState();
    return;
  }

  if (jackpot.refreshPending) {
    return;
  }

  jackpot.refreshPending = true;

  try {
    const [leader, lastWinner, pot, entryAmount, jackpotDuration, endsAt] = await Promise.all([
      jackpot.contract.leader(),
      jackpot.contract.lastWinner(),
      jackpot.contract.pot(),
      jackpot.contract.entryAmount(),
      jackpot.contract.jackpotDuration(),
      jackpot.contract.endsAt()
    ]);
    jackpot.state = { leader, lastWinner, pot, entryAmount, jackpotDuration, endsAt };
    jackpot.allowance = await jackpot.token.allowance(jackpot.account, jackpot.contractAddress);
    renderJackpotState();
  } catch (error) {
    setJackpotMessage(error?.message || "Could not refresh live jackpot state.");
  } finally {
    jackpot.refreshPending = false;
  }
}

async function connectJackpot() {
  if (!window.ethereum || !window.ethers) {
    setJackpotMessage("Install Rabby or another EVM wallet to play.");
    return;
  }

  if (!jackpot.contractAddress) {
    setJackpotMessage("Deploy the V2 claim-only jackpot contract, then add its address to the site.");
    return;
  }

  try {
    setJackpotMessage("Connecting wallet...");
    await ensureHyperEvm();

    jackpot.provider = new window.ethers.providers.Web3Provider(window.ethereum, "any");
    await jackpot.provider.send("eth_requestAccounts", []);
    jackpot.signer = jackpot.provider.getSigner();
    jackpot.account = await jackpot.signer.getAddress();
    jackpot.contract = new window.ethers.Contract(jackpot.contractAddress, jackpotAbi, jackpot.signer);
    jackpot.token = new window.ethers.Contract(jackpot.tokenAddress, tokenAbi, jackpot.signer);

    setJackpotMessage("Connected. Reading live jackpot...");
    await refreshJackpot();
    setJackpotMessage("Live on HyperEVM. Approve the entry amount, enter, then claim if you are leader when the clock hits zero.");
  } catch (error) {
    setJackpotMessage(error?.message || "Wallet connection failed.");
  }
}

async function runJackpotTx(label, action) {
  if (jackpot.txPending) {
    return;
  }

  try {
    jackpot.txPending = true;
    setJackpotButtons();
    await ensureHyperEvm();
    setJackpotMessage(`${label} transaction pending...`);
    const tx = await action();
    setJackpotMessage(`${label} sent. Waiting for confirmation...`);
    await tx.wait();
    await refreshJackpot();
    setJackpotMessage(`${label} confirmed.`);
  } catch (error) {
    setJackpotMessage(error?.data?.message || error?.message || `${label} failed.`);
  } finally {
    jackpot.txPending = false;
    setJackpotButtons();
  }
}

if (jackpotEls.clock) {
  jackpotEls.connect?.addEventListener("click", connectJackpot);
  jackpotEls.approve?.addEventListener("click", () => {
    if (!jackpot.token || !jackpot.state) return;
    runJackpotTx("Approve", () => jackpot.token.approve(jackpot.contractAddress, jackpot.state.entryAmount));
  });
  jackpotEls.enter?.addEventListener("click", () => {
    if (!jackpot.contract) return;
    runJackpotTx("Enter", () => jackpot.contract.enter());
  });
  jackpotEls.claim?.addEventListener("click", () => {
    if (!jackpot.contract) return;
    runJackpotTx("Claim", () => jackpot.contract.claimPrize());
  });

  setJackpotButtons();
  window.setInterval(() => {
    renderJackpotState();
  }, 1000);
  window.setInterval(() => {
    if (jackpot.account && !jackpot.txPending) {
      refreshJackpot();
    }
  }, 12000);

  window.ethereum?.on?.("accountsChanged", () => {
    window.location.reload();
  });
  window.ethereum?.on?.("chainChanged", () => {
    window.location.reload();
  });
}

const gameCanvas = document.querySelector("#zcrash-game");

if (gameCanvas) {
  const ctx = gameCanvas.getContext("2d");
  const playerImage = new Image();
  playerImage.src = "assets/zcrash-mascot.png";
  const scoreEl = document.querySelector("#game-score");
  const rankEl = document.querySelector("#game-rank");
  const livesEl = document.querySelector("#game-lives");
  const startButton = document.querySelector("#game-start");
  const resultEl = document.querySelector("#game-result");
  const resultTitle = resultEl?.querySelector("h3");
  const resultCopy = document.querySelector("#game-result-copy");

  const badItems = [
    "ZEC BAGS",
    "BOARD DRAMA",
    "PAID SHILL",
    "OPTIONAL PRIVACY",
    "EXIT LIQUIDITY",
    "INFLUENCER PUMP",
    "OLD TECH LARP",
    "TRUSTED SETUP",
    "NONPROFIT LAWYERS"
  ];

  const goodItems = [
    "FUD",
    "RECEIPTS",
    "HL BID",
    "MEMES",
    "SHORT BUTTON",
    "SOURCE?"
  ];

  const ranks = [
    [15000, "ZCRASH PROP DESK"],
    [7000, "PRIVACY MAXI"],
    [3000, "HL SCALPER"],
    [1000, "FUD INTERN"],
    [0, "BAGHOLDER"]
  ];

  const game = {
    running: false,
    keys: new Set(),
    items: [],
    particles: [],
    score: 0,
    lives: 3,
    lastSpawn: 0,
    lastTime: 0,
    shake: 0,
    multiplierUntil: 0,
    player: {
      x: gameCanvas.width / 2,
      y: gameCanvas.height - 86,
      width: 92,
      height: 132,
      speed: 520
    }
  };

  function rankFor(score) {
    return ranks.find(([threshold]) => score >= threshold)[1];
  }

  function updateHud() {
    scoreEl.textContent = String(Math.max(0, Math.floor(game.score)));
    rankEl.textContent = rankFor(game.score);
    livesEl.textContent = String(game.lives);
  }

  function resetGame() {
    game.running = true;
    game.items = [];
    game.particles = [];
    game.score = 0;
    game.lives = 3;
    game.lastSpawn = 0;
    game.lastTime = performance.now();
    game.shake = 0;
    game.multiplierUntil = 0;
    game.player.x = gameCanvas.width / 2;
    resultEl?.classList.remove("is-visible");
    startButton.textContent = "Restart Run";
    updateHud();
  }

  function spawnItem(time) {
    const isGood = Math.random() < 0.32;
    const text = isGood
      ? goodItems[Math.floor(Math.random() * goodItems.length)]
      : badItems[Math.floor(Math.random() * badItems.length)];
    const width = Math.max(86, text.length * 9 + 28);

    game.items.push({
      text,
      good: isGood,
      x: Math.random() * (gameCanvas.width - width - 24) + 12,
      y: -42,
      width,
      height: 38,
      speed: 125 + Math.random() * 105 + Math.min(game.score / 90, 110),
      wobble: Math.random() * Math.PI * 2,
      born: time
    });
  }

  function addPop(x, y, color, text) {
    game.particles.push({
      x,
      y,
      color,
      text,
      life: 0.7,
      vy: -60
    });
  }

  function rectsOverlap(a, b) {
    return (
      a.x < b.x + b.width &&
      a.x + a.width > b.x &&
      a.y < b.y + b.height &&
      a.y + a.height > b.y
    );
  }

  function handleCatch(item, time) {
    if (item.good) {
      const multiplier = time < game.multiplierUntil ? 2 : 1;
      game.score += item.text === "HL BID" ? 550 * multiplier : 320 * multiplier;
      addPop(item.x, item.y, "#2d6f82", `+${item.text}`);

      if (item.text === "FUD") {
        game.items = game.items.filter((falling) => falling.good);
        addPop(game.player.x, game.player.y - 30, "#d84b31", "FUD BLAST");
      }

      if (item.text === "RECEIPTS") {
        game.multiplierUntil = time + 5000;
        addPop(game.player.x, game.player.y - 56, "#e3aa2c", "2X RECEIPTS");
      }
    } else {
      game.lives -= 1;
      game.shake = 14;
      addPop(item.x, item.y, "#d84b31", `-${item.text}`);
    }
  }

  function endGame() {
    game.running = false;
    updateHud();

    if (resultTitle && resultCopy) {
      const rank = rankFor(game.score);
      const won = game.score >= 7000;
      resultTitle.textContent = won ? "YOU SAW THE MEMBRANE" : "YOU WERE THE EXIT";
      resultCopy.textContent = `score ${Math.floor(game.score)}. rank ${rank}. every run ends with receipts because vibes alone are how you get farmed.`;
    }

    resultEl?.classList.add("is-visible");
  }

  function drawBackground(time) {
    ctx.fillStyle = "#f5eddc";
    ctx.fillRect(0, 0, gameCanvas.width, gameCanvas.height);

    ctx.strokeStyle = "rgba(23, 23, 23, 0.12)";
    ctx.lineWidth = 1;
    for (let x = 0; x < gameCanvas.width; x += 48) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, gameCanvas.height);
      ctx.stroke();
    }
    for (let y = 0; y < gameCanvas.height; y += 48) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(gameCanvas.width, y);
      ctx.stroke();
    }

    ctx.strokeStyle = "#d84b31";
    ctx.lineWidth = 5;
    ctx.beginPath();
    for (let i = 0; i < 16; i += 1) {
      const x = (i / 15) * gameCanvas.width;
      const y = 90 + i * 20 + Math.sin(time / 320 + i) * 18;
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.stroke();

    ctx.fillStyle = "rgba(216, 75, 49, 0.08)";
    ctx.fillRect(0, gameCanvas.height - 86, gameCanvas.width, 86);
  }

  function drawPlayer() {
    const { x, y, width, height } = game.player;
    ctx.save();
    ctx.translate(x - width / 2, y - height / 2);

    ctx.fillStyle = "rgba(23, 23, 23, 0.18)";
    ctx.beginPath();
    ctx.ellipse(width / 2, height - 6, width * 0.42, 12, 0, 0, Math.PI * 2);
    ctx.fill();

    if (playerImage.complete && playerImage.naturalWidth > 0) {
      ctx.drawImage(playerImage, 0, 0, width, height);
    } else {
      ctx.fillStyle = "#e3aa2c";
      ctx.fillRect(0, 0, width, height);
      ctx.strokeStyle = "#171717";
      ctx.lineWidth = 4;
      ctx.strokeRect(0, 0, width, height);
      ctx.fillStyle = "#d84b31";
      ctx.font = "700 16px Archivo, Arial";
      ctx.textAlign = "center";
      ctx.fillText("ZCRASH", width / 2, height / 2);
    }

    ctx.restore();
  }

  function drawItem(item) {
    ctx.save();
    ctx.translate(item.x + item.width / 2, item.y + item.height / 2);
    ctx.rotate(Math.sin(item.wobble) * 0.05);
    ctx.fillStyle = item.good ? "#2d6f82" : "#d84b31";
    ctx.fillRect(-item.width / 2, -item.height / 2, item.width, item.height);
    ctx.strokeStyle = "#171717";
    ctx.lineWidth = 3;
    ctx.strokeRect(-item.width / 2, -item.height / 2, item.width, item.height);
    ctx.fillStyle = "#fffefa";
    ctx.font = "700 14px IBM Plex Mono, monospace";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(item.text, 0, 1);
    ctx.restore();
  }

  function drawParticles(delta) {
    game.particles = game.particles.filter((particle) => {
      particle.life -= delta;
      particle.y += particle.vy * delta;
      ctx.globalAlpha = Math.max(0, particle.life);
      ctx.fillStyle = particle.color;
      ctx.font = "700 18px IBM Plex Mono, monospace";
      ctx.textAlign = "center";
      ctx.fillText(particle.text, particle.x, particle.y);
      ctx.globalAlpha = 1;
      return particle.life > 0;
    });
  }

  function step(time) {
    const delta = Math.min((time - game.lastTime) / 1000, 0.04);
    game.lastTime = time;

    if (game.running) {
      if (game.keys.has("ArrowLeft") || game.keys.has("a")) {
        game.player.x -= game.player.speed * delta;
      }
      if (game.keys.has("ArrowRight") || game.keys.has("d")) {
        game.player.x += game.player.speed * delta;
      }

      game.player.x = Math.max(game.player.width / 2, Math.min(gameCanvas.width - game.player.width / 2, game.player.x));

      if (time - game.lastSpawn > Math.max(420, 920 - game.score / 16)) {
        spawnItem(time);
        game.lastSpawn = time;
      }

      game.score += delta * (time < game.multiplierUntil ? 46 : 23);

      const playerRect = {
        x: game.player.x - game.player.width / 2,
        y: game.player.y - game.player.height / 2,
        width: game.player.width,
        height: game.player.height
      };

      game.items.forEach((item) => {
        item.y += item.speed * delta;
        item.wobble += delta * 4;
      });

      game.items = game.items.filter((item) => {
        if (rectsOverlap(playerRect, item)) {
          handleCatch(item, time);
          return false;
        }
        return item.y < gameCanvas.height + 60;
      });

      if (game.lives <= 0) {
        endGame();
      }
    }

    ctx.save();
    if (game.shake > 0) {
      ctx.translate((Math.random() - 0.5) * game.shake, (Math.random() - 0.5) * game.shake);
      game.shake *= 0.82;
    }

    drawBackground(time);
    game.items.forEach(drawItem);
    drawPlayer();
    drawParticles(delta);
    ctx.restore();
    updateHud();

    window.requestAnimationFrame(step);
  }

  function movePlayerFromPointer(event) {
    const rect = gameCanvas.getBoundingClientRect();
    const scale = gameCanvas.width / rect.width;
    game.player.x = (event.clientX - rect.left) * scale;
  }

  startButton?.addEventListener("click", resetGame);
  window.addEventListener("keydown", (event) => {
    game.keys.add(event.key);
    if ((event.key === " " || event.key === "Enter") && !game.running) {
      resetGame();
    }
  });
  window.addEventListener("keyup", (event) => game.keys.delete(event.key));
  gameCanvas.addEventListener("pointermove", movePlayerFromPointer);
  gameCanvas.addEventListener("pointerdown", (event) => {
    movePlayerFromPointer(event);
    if (!game.running) {
      resetGame();
    }
  });

  updateHud();
  window.requestAnimationFrame(step);
}
