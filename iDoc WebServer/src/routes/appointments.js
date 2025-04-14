const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const Appointment = require('../models/Appointment');
const { auth } = require('../middleware/auth');

// Get appointments with filtering and pagination
router.get('/', auth, async (req, res) => {
    try {
        const {
            startDate,
            endDate,
            status,
            type,
            page = 1,
            limit = 10
        } = req.query;

        const query = { doctor: req.user._id };
        
        // Date range filter
        if (startDate && endDate) {
            query.date = {
                $gte: new Date(startDate),
                $lte: new Date(endDate)
            };
        }

        // Status filter
        if (status) {
            query.status = status;
        }

        // Type filter
        if (type) {
            query.type = type;
        }

        const skip = (page - 1) * limit;

        const appointments = await Appointment.find(query)
            .populate('patient', 'firstName lastName dateOfBirth')
            .sort({ date: 1 })
            .skip(skip)
            .limit(limit);

        const total = await Appointment.countDocuments(query);

        res.json({
            appointments,
            total,
            pages: Math.ceil(total / limit),
            currentPage: page
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get single appointment
router.get('/:id', auth, async (req, res) => {
    try {
        const appointment = await Appointment.findOne({
            _id: req.params.id,
            doctor: req.user._id
        }).populate('patient', 'firstName lastName dateOfBirth');

        if (!appointment) {
            return res.status(404).json({ message: 'Appointment not found' });
        }

        res.json(appointment);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Create new appointment
router.post('/', auth, [
    body('patient').isMongoId().withMessage('Valid patient ID is required'),
    body('date').isISO8601().withMessage('Valid date is required'),
    body('duration').isInt({ min: 15, max: 480 }).withMessage('Duration must be between 15 and 480 minutes'),
    body('type').isIn(['initial', 'follow-up', 'consultation', 'emergency', 'routine', 'procedure']).withMessage('Valid appointment type is required'),
    body('location').trim().notEmpty().withMessage('Location is required'),
    body('notes').optional().trim(),
    body('symptoms').optional().isArray(),
    body('recurring').optional().isObject()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const appointment = new Appointment({
            ...req.body,
            doctor: req.user._id
        });

        await appointment.save();
        res.status(201).json(appointment);
    } catch (error) {
        if (error.message === 'Appointment time conflicts with existing appointment') {
            return res.status(400).json({ message: error.message });
        }
        res.status(500).json({ message: 'Server error' });
    }
});

// Update appointment
router.put('/:id', auth, [
    body('date').optional().isISO8601(),
    body('duration').optional().isInt({ min: 15, max: 480 }),
    body('type').optional().isIn(['initial', 'follow-up', 'consultation', 'emergency', 'routine', 'procedure']),
    body('location').optional().trim().notEmpty(),
    body('notes').optional().trim(),
    body('symptoms').optional().isArray(),
    body('status').optional().isIn(['scheduled', 'confirmed', 'completed', 'cancelled', 'no-show']),
    body('diagnosis').optional().trim(),
    body('treatment').optional().trim(),
    body('followUpDate').optional().isISO8601()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const appointment = await Appointment.findOne({
            _id: req.params.id,
            doctor: req.user._id
        });

        if (!appointment) {
            return res.status(404).json({ message: 'Appointment not found' });
        }

        Object.keys(req.body).forEach(key => {
            if (req.body[key] !== undefined) {
                appointment[key] = req.body[key];
            }
        });

        await appointment.save();
        res.json(appointment);
    } catch (error) {
        if (error.message === 'Appointment time conflicts with existing appointment') {
            return res.status(400).json({ message: error.message });
        }
        res.status(500).json({ message: 'Server error' });
    }
});

// Add attachment to appointment
router.post('/:id/attachments', auth, [
    body('title').trim().notEmpty().withMessage('Title is required'),
    body('type').trim().notEmpty().withMessage('Type is required'),
    body('url').trim().notEmpty().withMessage('URL is required')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const appointment = await Appointment.findOne({
            _id: req.params.id,
            doctor: req.user._id
        });

        if (!appointment) {
            return res.status(404).json({ message: 'Appointment not found' });
        }

        appointment.attachments.push({
            ...req.body,
            uploadedBy: req.user._id
        });

        await appointment.save();
        res.json(appointment);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add reminder to appointment
router.post('/:id/reminders', auth, [
    body('type').isIn(['email', 'sms', 'push']).withMessage('Valid reminder type is required'),
    body('time').isInt({ min: 5, max: 1440 }).withMessage('Time must be between 5 and 1440 minutes')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const appointment = await Appointment.findOne({
            _id: req.params.id,
            doctor: req.user._id
        });

        if (!appointment) {
            return res.status(404).json({ message: 'Appointment not found' });
        }

        appointment.reminders.push(req.body);
        await appointment.save();
        res.json(appointment);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get daily schedule
router.get('/schedule/daily', auth, async (req, res) => {
    try {
        const { date } = req.query;
        const startDate = new Date(date);
        startDate.setHours(0, 0, 0, 0);
        const endDate = new Date(date);
        endDate.setHours(23, 59, 59, 999);

        const appointments = await Appointment.find({
            doctor: req.user._id,
            date: {
                $gte: startDate,
                $lte: endDate
            }
        })
        .populate('patient', 'firstName lastName dateOfBirth')
        .sort({ date: 1 });

        res.json(appointments);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get weekly schedule
router.get('/schedule/weekly', auth, async (req, res) => {
    try {
        const { startDate } = req.query;
        const weekStart = new Date(startDate);
        weekStart.setHours(0, 0, 0, 0);
        const weekEnd = new Date(startDate);
        weekEnd.setDate(weekEnd.getDate() + 6);
        weekEnd.setHours(23, 59, 59, 999);

        const appointments = await Appointment.find({
            doctor: req.user._id,
            date: {
                $gte: weekStart,
                $lte: weekEnd
            }
        })
        .populate('patient', 'firstName lastName dateOfBirth')
        .sort({ date: 1 });

        res.json(appointments);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get monthly schedule
router.get('/schedule/monthly', auth, async (req, res) => {
    try {
        const { year, month } = req.query;
        const startDate = new Date(year, month - 1, 1);
        const endDate = new Date(year, month, 0, 23, 59, 59, 999);

        const appointments = await Appointment.find({
            doctor: req.user._id,
            date: {
                $gte: startDate,
                $lte: endDate
            }
        })
        .populate('patient', 'firstName lastName dateOfBirth')
        .sort({ date: 1 });

        res.json(appointments);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router; 