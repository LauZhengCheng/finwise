// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : notificationController.js
// Description   : FCM token registration and notification history.
//                 Bell icon reads from here — all proactive ai_logs rows.
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

const supabase = require('../config/supabase');

// POST /api/notifications/register-token
// Called on every app open with the latest FCM token.
// Evicts the token from all other profiles first — one device token = one active account.
const registerToken = async (req, res) => {
  try {
    const userId = req.user.id;
    const { fcm_token } = req.body;

    if (!fcm_token) return res.status(400).json({ error: 'fcm_token is required' });

    await supabase
      .from('profiles')
      .update({ fcm_token: null })
      .eq('fcm_token', fcm_token)
      .neq('id', userId);

    const { error } = await supabase
      .from('profiles')
      .update({ fcm_token })
      .eq('id', userId);

    if (error) return res.status(500).json({ error: error.message });
    return res.json({ success: true });
  } catch (error) {
    console.error('registerToken error:', error.message);
    res.status(500).json({ error: 'Failed to register token' });
  }
};

// DELETE /api/notifications/clear-token
// Called on logout — removes this device's FCM token from the user's profile
// so they stop receiving push notifications after signing out.
const clearToken = async (req, res) => {
  try {
    const userId = req.user.id;

    const { error } = await supabase
      .from('profiles')
      .update({ fcm_token: null })
      .eq('id', userId);

    if (error) return res.status(500).json({ error: error.message });
    return res.json({ success: true });
  } catch (error) {
    console.error('clearToken error:', error.message);
    res.status(500).json({ error: 'Failed to clear token' });
  }
};

// GET /api/notifications/history
// Returns all proactive messages for the bell icon notification list.
// Each item includes whether the user has replied after it (for dimming).
const getNotificationHistory = async (req, res) => {
  try {
  const userId = req.user.id;

  const { data: notifications, error } = await supabase
    .from('ai_logs')
    .select('id, ai_response, created_at')
    .eq('user_id', userId)
    .eq('is_proactive', true)
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) return res.status(500).json({ error: error.message });

  if (!notifications?.length) return res.json({ notifications: [] });

  // Find the latest of: user's last chat open OR last chat reply
  const [{ data: lastReply }, { data: profile }] = await Promise.all([
    supabase.from('ai_logs').select('created_at')
      .eq('user_id', userId).eq('interaction_type', 'chat')
      .order('created_at', { ascending: false }).limit(1).single(),
    supabase.from('profiles').select('chat_opened_at').eq('id', userId).single(),
  ]);

  const lastReplyAt = lastReply?.created_at ? new Date(lastReply.created_at) : null;
  const chatOpenedAt = profile?.chat_opened_at ? new Date(profile.chat_opened_at) : null;

  // Use whichever is more recent — reply or chat open
  let lastSeenAt = null;
  if (lastReplyAt && chatOpenedAt) {
    lastSeenAt = lastReplyAt > chatOpenedAt ? lastReplyAt : chatOpenedAt;
  } else {
    lastSeenAt = lastReplyAt || chatOpenedAt;
  }

  const result = notifications.map((n) => ({
    id: n.id,
    message: typeof n.ai_response === 'string' ? n.ai_response : n.ai_response?.message,
    created_at: n.created_at,
    is_replied: lastSeenAt ? new Date(n.created_at) < lastSeenAt : false,
  }));

  const unread_count = result.filter((n) => !n.is_replied).length;

  return res.json({ notifications: result, unread_count });
  } catch (error) {
    console.error('getNotificationHistory error:', error.message);
    res.status(500).json({ error: 'Failed to load notifications' });
  }
};

const markChatOpened = async (req, res) => {
  try {
    await supabase.from('profiles').update({ chat_opened_at: new Date().toISOString() })
      .eq('id', req.user.id);
    return res.json({ success: true });
  } catch (error) {
    console.error('markChatOpened error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { registerToken, clearToken, getNotificationHistory, markChatOpened };
