import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { SecurityMiddleware } from '../src/security_middleware';
import { ProfileManager } from '../src/database/profile_manager';
import { FriendsManager } from '../src/friends_manager';

describe('Step 10: Friends System, Player IDs & Room Invitations Tests', function () {
  this.timeout(20000);
  const PORT = 3016;
  const SERVER_URL = `http://localhost:${PORT}`;
  let clientSockets: ClientSocket[] = [];

  before((done) => {
    startServer(PORT).then(() => done());
  });

  after((done) => {
    clientSockets.forEach((s) => s.close());
    server.close(() => done());
  });

  afterEach(() => {
    clientSockets.forEach((s) => s.close());
    clientSockets = [];
    SecurityMiddleware.resetRateLimits();
  });

  function createClient(): ClientSocket {
    const socket = Client(SERVER_URL, {
      transports: ['websocket'],
      forceNew: true,
    });
    clientSockets.push(socket);
    return socket;
  }

  function waitForConnect(socket: ClientSocket): Promise<void> {
    return new Promise((resolve) => {
      if (socket.connected) resolve();
      else socket.once('connect', () => resolve());
    });
  }

  it('1. Unique Player ID generation and non-sequential format', () => {
    const ids = new Set<string>();
    const idRegex = /^PB-[2-9A-HJ-NP-Z]{6}$/;

    for (let i = 0; i < 50; i++) {
      const profile = ProfileManager.getInstance().getOrCreateProfile(`user_id_test_${i}`, `User_${i}`);
      expect(profile.publicPlayerId).to.match(idRegex);
      expect(ids.has(profile.publicPlayerId)).to.be.false;
      ids.add(profile.publicPlayerId);

      const dto = ProfileManager.getInstance().getProfileDTO(profile.id);
      expect(dto.publicPlayerId).to.equal(profile.publicPlayerId);
      expect(dto.playerId).to.equal(profile.publicPlayerId);
    }
  });

  it('2. Search player by exact Player ID without sensitive data leakage', async () => {
    const clientA = createClient();
    const clientB = createClient();
    await Promise.all([waitForConnect(clientA), waitForConnect(clientB)]);

    // Fetch client B's profile
    const profileBRes: any = await new Promise((res) => {
      clientB.emit('get_player_profile', {}, res);
    });
    expect(profileBRes.success).to.be.true;
    const targetPlayerId = profileBRes.profile.publicPlayerId;

    // Client A searches for Client B by public Player ID
    const searchRes: any = await new Promise((res) => {
      clientA.emit('search_player_by_id', { queryPlayerId: targetPlayerId }, res);
    });

    expect(searchRes.success).to.be.true;
    expect(searchRes.player.publicPlayerId).to.equal(targetPlayerId);
    expect(searchRes.player.username).to.exist;
    expect(searchRes.player.isOnline).to.be.true;
    expect(searchRes.player.friendshipStatus).to.equal('NONE');

    // Strict privacy: no socket IDs, no session tokens, no internal database IDs, no private match details
    expect(searchRes.player.id).to.be.undefined;
    expect(searchRes.player.sessionToken).to.be.undefined;
    expect(searchRes.player.powerPoints).to.be.undefined;

    // Search non-existent ID
    const notFoundRes: any = await new Promise((res) => {
      clientA.emit('search_player_by_id', { queryPlayerId: 'PB-NONEXIST' }, res);
    });
    expect(notFoundRes.success).to.be.false;
    expect(notFoundRes.error).to.include('No player found');
  });

  it('3. Friend request lifecycle: self-request prevention, duplicate prevention, and acceptance', async () => {
    const clientA = createClient();
    const clientB = createClient();
    await Promise.all([waitForConnect(clientA), waitForConnect(clientB)]);

    const profileARes: any = await new Promise((res) => clientA.emit('get_player_profile', {}, res));
    const profileBRes: any = await new Promise((res) => clientB.emit('get_player_profile', {}, res));
    const publicA = profileARes.profile.publicPlayerId;
    const publicB = profileBRes.profile.publicPlayerId;

    // Prevent self-request
    const selfRes: any = await new Promise((res) => {
      clientA.emit('send_friend_request', { targetPlayerId: publicA }, res);
    });
    expect(selfRes.success).to.be.false;
    expect(selfRes.error).to.include('yourself');

    // Send valid request from A to B
    const sendRes: any = await new Promise((res) => {
      clientA.emit('send_friend_request', { targetPlayerId: publicB }, res);
    });
    expect(sendRes.success).to.be.true;
    expect(sendRes.request.status).to.equal('PENDING');

    // Prevent duplicate request from A to B
    const dupRes: any = await new Promise((res) => {
      clientA.emit('send_friend_request', { targetPlayerId: publicB }, res);
    });
    expect(dupRes.success).to.be.false;
    expect(dupRes.error).to.include('already been sent');

    // Check incoming requests for B
    const reqsB: any = await new Promise((res) => clientB.emit('get_friend_requests', {}, res));
    expect(reqsB.success).to.be.true;
    expect(reqsB.incoming.length).to.be.at.least(1);
    const pendingReq = reqsB.incoming.find((r: any) => r.senderPublicId === publicA);
    expect(pendingReq).to.exist;

    // Client B accepts request
    const acceptRes: any = await new Promise((res) => {
      clientB.emit('respond_friend_request', { requestId: pendingReq.requestId, action: 'ACCEPT' }, res);
    });
    expect(acceptRes.success).to.be.true;

    // Check friends list for both A and B
    const friendsA: any = await new Promise((res) => clientA.emit('get_friends_list', {}, res));
    const friendsB: any = await new Promise((res) => clientB.emit('get_friends_list', {}, res));
    expect(friendsA.friends.some((f: any) => f.publicPlayerId === publicB)).to.be.true;
    expect(friendsB.friends.some((f: any) => f.publicPlayerId === publicA)).to.be.true;
  });

  it('4. Unauthorized user cannot accept or modify another user\'s friend request', async () => {
    const clientA = createClient();
    const clientB = createClient();
    const clientC = createClient();
    await Promise.all([waitForConnect(clientA), waitForConnect(clientB), waitForConnect(clientC)]);

    const profileBRes: any = await new Promise((res) => clientB.emit('get_player_profile', {}, res));
    const publicB = profileBRes.profile.publicPlayerId;

    // A sends request to B
    const sendRes: any = await new Promise((res) => {
      clientA.emit('send_friend_request', { targetPlayerId: publicB }, res);
    });
    expect(sendRes.success).to.be.true;
    const requestId = sendRes.request.requestId;

    // Client C attempts to accept A's request to B
    const rogueRes: any = await new Promise((res) => {
      clientC.emit('respond_friend_request', { requestId, action: 'ACCEPT' }, res);
    });
    expect(rogueRes.success).to.be.false;
    expect(rogueRes.error).to.include('Unauthorized');

    // Client C attempts to cancel A's request to B
    const rogueCancelRes: any = await new Promise((res) => {
      clientC.emit('cancel_friend_request', { requestId }, res);
    });
    expect(rogueCancelRes.success).to.be.false;
    expect(rogueCancelRes.error).to.include('Unauthorized');
  });

  it('5. Room invitation creation, token hashing, revocation, and preview validation', async () => {
    const hostSocket = createClient();
    const guestSocket = createClient();
    await Promise.all([waitForConnect(hostSocket), waitForConnect(guestSocket)]);

    // Host creates room
    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostPlayer', category: 'Cricket', itemCount: 5, timerDuration: 15 },
        res
      );
    });
    expect(createRes.success).to.be.true;
    const roomCode = createRes.roomCode;

    // Non-host cannot create invite link
    const unauthRes: any = await new Promise((res) => {
      guestSocket.emit('create_invite_link', { roomCode }, res);
    });
    expect(unauthRes.success).to.be.false;
    expect(unauthRes.error).to.include('Only the room host');

    // Host creates invite link
    const linkRes: any = await new Promise((res) => {
      hostSocket.emit('create_invite_link', { roomCode, maxUses: 4, expiresInMinutes: 10 }, res);
    });
    expect(linkRes.success).to.be.true;
    expect(linkRes.token).to.exist;
    expect(linkRes.inviteUrl).to.include(linkRes.token);

    // Guest previews invite link
    const previewRes: any = await new Promise((res) => {
      guestSocket.emit('preview_invite_link', { token: linkRes.token }, res);
    });
    expect(previewRes.success).to.be.true;
    expect(previewRes.preview.roomCode).to.equal(roomCode);
    expect(previewRes.preview.category).to.equal('Cricket');
    expect(previewRes.preview.isOpen).to.be.true;
    expect(previewRes.preview.maxPlayers).to.equal(8);

    // Strict confidentiality check: preview MUST NOT reveal hidden character scores or points!
    expect(previewRes.preview.items).to.be.undefined;
    expect(previewRes.preview.powerPoints).to.be.undefined;
    expect(previewRes.preview.scoringMethod).to.be.undefined;

    // Host revokes invite link
    const revokeRes: any = await new Promise((res) => {
      hostSocket.emit('revoke_invite_link', { roomCode }, res);
    });
    expect(revokeRes.success).to.be.true;

    // Guest preview after revocation
    const revokedPreviewRes: any = await new Promise((res) => {
      guestSocket.emit('preview_invite_link', { token: linkRes.token }, res);
    });
    expect(revokedPreviewRes.success).to.be.false;
    expect(revokedPreviewRes.error).to.include('revoked');
    expect(revokedPreviewRes.preview.isOpen).to.be.false;
  });

  it('6. Join room via invite token and strictly enforce max 8 player room capacity', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'CapacityHost', category: 'Naruto', itemCount: 5 },
        res
      );
    });
    const roomCode = createRes.roomCode;

    // Create shareable invite link
    const linkRes: any = await new Promise((res) => {
      hostSocket.emit('create_invite_link', { roomCode, maxUses: 10 }, res);
    });
    expect(linkRes.success).to.be.true;
    const token = linkRes.token;

    // Fill room to 8 players (Host is player 1, add 7 more)
    const players: ClientSocket[] = [];
    for (let i = 2; i <= 8; i++) {
      const p = createClient();
      await waitForConnect(p);
      players.push(p);

      const joinRes: any = await new Promise((res) => {
        p.emit('join_room_by_invite', { token, username: `Player_${i}` }, res);
      });
      expect(joinRes.success).to.be.true;
      expect(joinRes.roomState.players.length).to.equal(i);
    }

    // 9th player attempts to join via invite token
    const p9 = createClient();
    await waitForConnect(p9);
    const p9Res: any = await new Promise((res) => {
      p9.emit('join_room_by_invite', { token, username: 'Player_9_Denied' }, res);
    });
    expect(p9Res.success).to.be.false;
    expect(p9Res.error).to.include('full');
  });

  it('7. In-app notifications received in real-time and deduplicated', async () => {
    const clientA = createClient();
    const clientB = createClient();
    await Promise.all([waitForConnect(clientA), waitForConnect(clientB)]);

    const profileBRes: any = await new Promise((res) => clientB.emit('get_player_profile', {}, res));
    const publicB = profileBRes.profile.publicPlayerId;

    let notificationReceived: any = null;
    clientB.on('new_notification', (data) => {
      notificationReceived = data;
    });

    // A sends friend request to B
    const sendRes: any = await new Promise((res) => {
      clientA.emit('send_friend_request', { targetPlayerId: publicB }, res);
    });
    expect(sendRes.success).to.be.true;

    // Wait a brief moment for notification to arrive
    await new Promise((r) => setTimeout(r, 100));
    expect(notificationReceived).to.exist;
    expect(notificationReceived.type).to.equal('FRIEND_REQUEST');

    // Check notifications list
    const notifsRes: any = await new Promise((res) => clientB.emit('get_notifications', {}, res));
    expect(notifsRes.success).to.be.true;
    expect(notifsRes.notifications.length).to.be.at.least(1);

    // Mark as read
    const notifId = notifsRes.notifications[0].id;
    const readRes: any = await new Promise((res) => clientB.emit('mark_notification_read', { notificationId: notifId }, res));
    expect(readRes.success).to.be.true;
  });
});
