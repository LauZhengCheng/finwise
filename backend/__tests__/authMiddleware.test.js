// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : authMiddleware.test.js
// Description   : Unit tests 5.2.8 — JWT authentication middleware
//                 (AM01–AM05). Supabase Auth is mocked; verifies
//                 header parsing, token rejection, and identity scoping.
// First Written : 18-07-2026
// Edited on     : 18-07-2026
// ============================================

jest.mock('../config/supabase', () => ({
    auth: { getUser: jest.fn() },
  }));
  
  const supabase = require('../config/supabase');
  const authenticateUser = require('../middleware/auth');
  


  // ── Helpers ──
  const makeReq = (authHeader, body = {}) => ({
    headers: authHeader ? { authorization: authHeader } : {},
    body,
  });
  const makeRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
  };
  
  beforeEach(() => supabase.auth.getUser.mockReset());
  


  // ── 5.2.8 Authentication Middleware (JWT Verification & Security) ──
  describe('5.2.8 Authentication Middleware — authenticateUser()', () => {
  
    test('AM01: valid JWT → req.user populated, next() called', async () => {
      supabase.auth.getUser.mockResolvedValue({
        data: { user: { id: 'user-a-uuid', email: 'usera@mail.com' } },
        error: null,
      });
      const req = makeReq('Bearer valid.jwt.token');
      const res = makeRes();
      const next = jest.fn();
  
      await authenticateUser(req, res, next);

      /*----------------------------------------------------*/
  
      expect(req.user.id).toBe('user-a-uuid');
      expect(req.user.email).toBe('usera@mail.com');
      expect(next).toHaveBeenCalled();           // request forwarded to controller
      expect(res.status).not.toHaveBeenCalled(); // no error response
    });
  
    test('AM02: expired token → HTTP 401, controller never invoked', async () => {
      supabase.auth.getUser.mockResolvedValue({
        data: { user: null },
        error: { message: 'JWT expired' },
      });
      const req = makeReq('Bearer expired.jwt.token');
      const res = makeRes();
      const next = jest.fn();
  
      await authenticateUser(req, res, next);

      /*----------------------------------------------------*/
  
      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: 'Invalid or expired token',
      }));
      expect(next).not.toHaveBeenCalled();
      expect(req.user).toBeUndefined();
    });
  
    test('AM03: no Authorization header → immediate 401, Supabase never queried', async () => {
      const req = makeReq(null);
      const res = makeRes();
      const next = jest.fn();
  
      await authenticateUser(req, res, next);

      /*----------------------------------------------------*/
  
      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: 'Missing or invalid authorization header',
      }));
      expect(supabase.auth.getUser).not.toHaveBeenCalled(); // early exit — no network
      expect(next).not.toHaveBeenCalled();
    });
  
    test('AM04: malformed token → Supabase rejects it, 401 returned', async () => {
      supabase.auth.getUser.mockResolvedValue({
        data: { user: null },
        error: { message: 'invalid JWT structure' },
      });
      const req = makeReq('Bearer invalidtoken123');
      const res = makeRes();
      const next = jest.fn();
  
      await authenticateUser(req, res, next);

      /*----------------------------------------------------*/
  
      expect(supabase.auth.getUser).toHaveBeenCalledWith('invalidtoken123');
      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });
  
    test('AM05: identity comes from the token — client-claimed user_id is ignored', async () => {
      supabase.auth.getUser.mockResolvedValue({
        data: { user: { id: 'user-a-uuid', email: 'usera@mail.com' } },
        error: null,
      });
      // Attacker sends User A's valid token but claims to be User B in the body
      const req = makeReq('Bearer user-a-token', { user_id: 'user-b-uuid' });
      const res = makeRes();
      const next = jest.fn();
  
      await authenticateUser(req, res, next);

      /*----------------------------------------------------*/
  
      expect(req.user.id).toBe('user-a-uuid');       // token wins
      expect(req.user.id).not.toBe('user-b-uuid');   // body claim never used
      expect(next).toHaveBeenCalled();
    });
  });
  