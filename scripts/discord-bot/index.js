const {
  Client,
  GatewayIntentBits,
  EmbedBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  Events,
  AttachmentBuilder,
  PermissionsBitField
} = require('discord.js');
const path = require('path');
const dotenv = require('dotenv');

// scripts/discord-bot/.env dosyasını garantili olarak yükle
dotenv.config({ path: path.join(__dirname, '.env') });
dotenv.config();

const { renderPlayerCard } = require('./cardRenderer');

const TOKEN = (process.env.DISCORD_TOKEN || '').trim();
const VODOO_APP_ID = process.env.DISCORD_CLIENT_ID || '';
const VODOO_GUILD_ID = process.env.DISCORD_GUILD_ID || '';
const VODOO_INVITE_URL = process.env.DISCORD_INVITE_URL || '';

// Anti-Spam Cooldown
const cooldowns = new Map();
const COOLDOWN_MS = 3000;

// Gateway Intents
const INTENTS = [
  GatewayIntentBits.Guilds,
  GatewayIntentBits.GuildMessages,
  GatewayIntentBits.MessageContent,
  GatewayIntentBits.GuildPresences,
  GatewayIntentBits.GuildMembers
];

const client = new Client({ intents: INTENTS });

// Yerel Port 9864 REST API'den canlı şarkı durumunu çekme
async function fetchLocalVodooState() {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2000);
    const res = await fetch('http://127.0.0.1:9864/api/v1/state', {
      signal: controller.signal
    });
    clearTimeout(timeout);
    if (res.ok) {
      const data = await res.json();
      if (data && (data.track || data.status === 'playing')) {
        return data;
      }
    }
  } catch (e) {
    // Local API not responding or desktop app closed
  }
  return null;
}

client.once(Events.ClientReady, (readyClient) => {
  console.log(`\n========================================`);
  console.log(`💜 Vodoo Music Discord Botu Başarıyla Aktif Edildi!`);
  console.log(`🤖 Bot Kullanıcı Adı: ${readyClient.user.tag} (ID: ${readyClient.user.id})`);
  console.log(`🎵 Dinleme Komutları: vodoo.music | .vodoo | !vodoo`);
  console.log(`📡 Port 9864 Yerel Ses Köprüsü: Dinlemede`);
  console.log(`🌐 Davet / Birlikte Dinle Bağlantısı: ${VODOO_INVITE_URL}`);
  console.log(`========================================\n`);
});

client.on(Events.MessageCreate, async (message) => {
  if (message.author.bot) return;

  const content = message.content.trim().toLowerCase();
  const isVodooCmd = content === 'vodoo.music' ||
                     content.startsWith('vodoo.music ') ||
                     content === '.vodoo' ||
                     content === '.vodoo.music' ||
                     content === '!vodoo';

  if (!isVodooCmd) return;

  console.log(`[Vodoo Bot] Komut alındı: "${message.content}" | Kullanıcı: ${message.author.tag}`);

  // Guild filter (if set in .env)
  if (VODOO_GUILD_ID && message.guild && message.guild.id !== VODOO_GUILD_ID) {
    return;
  }

  // Anti-Spam Rate Limit
  const now = Date.now();
  const userCooldown = cooldowns.get(message.author.id);
  if (userCooldown && now < userCooldown) {
    const remaining = Math.ceil((userCooldown - now) / 1000);
    try {
      const warn = await message.reply(`⏳ Çok hızlısın! Lütfen **${remaining}** saniye sonra tekrar dene.`);
      setTimeout(() => { try { warn.delete(); } catch (e) {} }, 2500);
    } catch (e) {}
    return;
  }
  cooldowns.set(message.author.id, now + COOLDOWN_MS);

  // Permission check
  if (message.guild && message.channel && message.guild.members?.me) {
    try {
      const perms = message.channel.permissionsFor(message.guild.members.me);
      if (perms && !perms.has(PermissionsBitField.Flags.SendMessages)) {
        return;
      }
    } catch (e) {}
  }

  // 1. ÖNCELİK: Yerel Port 9864 REST API
  const localState = await fetchLocalVodooState();

  // 2. ÖNCELİK: Discord Gateway Presence (Vodoo RPC)
  let member = message.member;
  if (!member?.presence && message.guild) {
    try {
      member = await message.guild.members.fetch({ user: message.author.id, withPresences: true, force: true });
    } catch (err) {}
  }

  const activities = member?.presence?.activities || [];
  const activity = activities.find(a => 
    (a.applicationId && String(a.applicationId) === String(VODOO_APP_ID)) ||
    (a.name && (
      a.name.toLowerCase().includes('vodoo') ||
      a.name.toLowerCase() === 'music'
    ))
  );

  let trackInfo = null;

  if (localState && localState.track) {
    trackInfo = {
      id: localState.track.id || null,
      title: localState.track.title,
      artist: localState.track.artist,
      album: localState.track.album || 'Vodoo Music',
      coverUrl: localState.track.thumbnail || null,
      currentSec: localState.currentTime || 0,
      durationSec: localState.duration || localState.track.duration || 0
    };
  } else if (activity) {
    const elapsed = activity.timestamps?.start ? Math.max(0, (Date.now() - activity.timestamps.start) / 1000) : 0;
    const dur = (activity.timestamps?.end && activity.timestamps?.start) ? (activity.timestamps.end - activity.timestamps.start) / 1000 : 0;
    trackInfo = {
      title: activity.details || 'Bilinmeyen Parça',
      artist: activity.state ? activity.state.replace(/^by\s+/i, '') : 'Vodoo Music',
      album: 'Vodoo Music',
      coverUrl: activity.assets?.largeImageURL?.() || null,
      currentSec: elapsed,
      durationSec: dur
    };
  }

  // Eğer hiçbir yerde çalan şarkı bulunamadıysa
  if (!trackInfo) {
    const notPlayingEmbed = new EmbedBuilder()
      .setColor('#C51D20')
      .setTitle('🎵 Aktif Şarkı Bulunamadı')
      .setDescription(
        `Hey <@${message.author.id}>, şu anda **Vodoo Music** üzerinde dinlediğin bir şarkı tespit edilemedi!\n\n` +
        `**Nasıl Çalışır?**\n` +
        `1. Bilgisayarında **Vodoo Music** masaüstü uygulamasını aç.\n` +
        `2. Ayarlar menüsünden **Discord RPC** seçeneğinin açık olduğundan emin ol.\n` +
        `3. İstediğin bir şarkıyı çal ve bu kanala tekrar **\`vodoo.music\`** yaz!\n\n` +
        `💡 *İpucu: Uygulama açıkken Port 9864 yerel köprüsü sayesinde çalan parçan otomatik algılanır.*`
      )
      .setFooter({ text: 'Vodoo Music • Luxury Audio Engine', iconURL: client.user.displayAvatarURL() });

    try {
      await message.reply({ embeds: [notPlayingEmbed] });
    } catch (e) {
      console.error('[Vodoo Bot] Reply error:', e);
    }
    return;
  }

  // Kart Oluşturma (Canvas) — görsel "NOW PLAYING" kartı (webhook ile aynı tasarım)
  try {
    const cardBuffer = await renderPlayerCard({
      title: trackInfo.title,
      artist: trackInfo.artist,
      album: trackInfo.album,
      coverUrl: trackInfo.coverUrl,
      currentSec: trackInfo.currentSec,
      durationSec: trackInfo.durationSec,
      username: message.author.username,
      avatarUrl: message.author.displayAvatarURL(),
      appLabel: 'Vodoo Music'
    });

    const attachment = new AttachmentBuilder(cardBuffer, { name: 'vodoo-now-playing.png' });

    // Butonlar
    const buttons = [];
    if (VODOO_INVITE_URL) {
      buttons.push(
        new ButtonBuilder()
          .setLabel('💜 Discord Sunucusu')
          .setStyle(ButtonStyle.Link)
          .setURL(VODOO_INVITE_URL)
      );
    }
    buttons.push(
      new ButtonBuilder()
        .setLabel('🎵 Vodoo Masaüstü')
        .setStyle(ButtonStyle.Link)
        .setURL('https://vodoomusic.vercel.app/indir')
    );
    buttons.push(
      new ButtonBuilder()
        .setCustomId('btn_vodoo_refresh')
        .setLabel('🔄 Yenile')
        .setStyle(ButtonStyle.Secondary)
    );
    // Birlikte Dinle partisi: konum bilgisiyle site/uç nokta linki (yalnizca track id varsa)
    if (trackInfo.id) {
      buttons.push(
        new ButtonBuilder()
          .setLabel('🎧 Birlikte Dinle')
          .setStyle(ButtonStyle.Link)
          .setURL(`https://vodoomusic.vercel.app/party?id=${encodeURIComponent(trackInfo.id)}&t=${Math.max(0, Math.floor(trackInfo.currentSec || 0))}`)
      );
    }
    const row = new ActionRowBuilder().addComponents(buttons);

    await message.reply({
      files: [attachment],
      components: [row]
    });
  } catch (err) {
    console.error('[Vodoo Bot] Kart render hatası:', err);
    await message.reply(`🎵 **Şu anda dinleniyor:** **${trackInfo.title}** - *${trackInfo.artist}*`);
  }
});

// Interactive Button Interactions
client.on(Events.InteractionCreate, async (interaction) => {
  if (!interaction.isButton()) return;
  if (interaction.customId === 'btn_vodoo_refresh') {
    await interaction.reply({
      content: '🔄 Şarkı durumu güncelleniyor! Tekrar **`vodoo.music`** yazarak en güncel kartı alabilirsin.',
      ephemeral: true
    });
  }
});

// Global Hata Koruma Kalkanı (Botun beklenmedik anlarda çökmesini engeller)
process.on('unhandledRejection', (reason) => {
  console.warn('[Vodoo Bot] ⚠️ Yakalanmamış Promise Reddi:', reason && reason.message ? reason.message : reason);
});

process.on('uncaughtException', (err) => {
  console.error('[Vodoo Bot] ⚠️ Beklenmeyen Hata:', err && err.message ? err.message : err);
});

if (!TOKEN) {
  console.warn('⚠️ DISCORD_TOKEN bulunamadı. Bot başlatılmadı.');
  console.log('💡 İpucu: Discord botunu aktif etmek için scripts/discord-bot/.env dosyasına DISCORD_TOKEN=<bot_token> ekleyin.');
} else {
  client.login(TOKEN).catch(err => {
    console.warn('[Vodoo Bot] ⚠️ Discord oturum açma hatası (TOKEN geçersiz veya eksik izinler):', err.message);
  });
}

module.exports = { client };
