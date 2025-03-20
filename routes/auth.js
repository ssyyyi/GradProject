const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../config/db'); // db.js에서 export한 db 객체
const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET; // .env에 저장된 JWT 시크릿 키

// 회원가입 API
router.post('/signup', async (req, res) => {
    const { email, password, name, age, birthdate, gender } = req.body;

    if (!email || !password || !name || !age || !birthdate || !gender) {
        return res.status(400).json({ error: '모든 필드를 입력해야 합니다.' });
    }

    try {
        // 이메일 중복 체크
        const [existingUser] = await db.query('SELECT * FROM users WHERE email = ?', [email]);
        if (existingUser.length > 0) {
            return res.status(409).json({ error: '이미 존재하는 이메일입니다.' });
        }

        // 비밀번호 해시 처리
        const hashedPassword = await bcrypt.hash(password, 10);

        // 사용자 저장
        await db.query(
            'INSERT INTO users (email, password, name, age, birthdate, gender) VALUES (?, ?, ?, ?, ?, ?)',
            [email, hashedPassword, name, age, birthdate, gender]
        );

        res.status(201).json({ message: '회원가입 성공!' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: '서버 오류' });
    }
});

router.post('/login', async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: '이메일과 비밀번호를 입력해야 합니다.' });
    }

    try {
        // 사용자 검색
        const [users] = await db.query('SELECT * FROM users WHERE email = ?', [email]);
        const user = users[0];

        if (!user) {
            return res.status(401).json({ error: '이메일 또는 비밀번호가 올바르지 않습니다.' });
        }

        // 비밀번호 검증
        const isPasswordValid = await bcrypt.compare(password, user.password);
        if (!isPasswordValid) {
            return res.status(401).json({ error: '이메일 또는 비밀번호가 올바르지 않습니다.' });
        }

        // JWT 생성
        const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, {
            expiresIn: '1h', // 토큰 만료 시간 (1시간)
        });

        // 선호 스타일 확인
        const needsPreferenceSelection = !user.prefer || user.prefer.trim() === '';

        res.json({
            message: '로그인 성공',
            token,
            user_id: user.email,
            needsPreferenceSelection
        });

    } catch (error) {
        console.error(error);
        res.status(500).json({ error: '서버 오류' });
    }
});

// 토큰 검증 미들웨어
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // "Bearer <token>"에서 토큰만 추출

    if (!token) {
        return res.status(401).json({ error: '토큰이 필요합니다.' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: '토큰이 유효하지 않습니다.' });
        }
        req.user = user; // 토큰에서 가져온 사용자 정보 저장
        next();
    });
};

router.post('/prefer', authenticateToken, async (req, res) => {
    const { prefer } = req.body;
    const userId = req.user.email; // JWT에서 사용자 정보 추출

    if (!prefer) {
        return res.status(400).json({ error: '선호 스타일을 입력해야 합니다.' });
    }

    try {
        await db.query('UPDATE users SET prefer = ? WHERE email = ?', [prefer, userId]);
        res.json({ message: '선호 스타일이 저장되었습니다.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: '서버 오류' });
    }
});

router.get('/profile', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.email; // JWT에서 사용자 정보 추출
        const [userProfile] = await db.query('SELECT * FROM users WHERE email = ?', [userId]);
        res.json({ profile: userProfile });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: '서버 오류' });
    }
});


module.exports = router;  // router 객체만 내보내기
