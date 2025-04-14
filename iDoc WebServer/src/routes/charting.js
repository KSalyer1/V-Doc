const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const Charting = require('../models/Charting');
const { auth } = require('../middleware/auth');

// Get all charting entries for a patient
router.get('/patient/:patientId', auth, async (req, res) => {
    try {
        const {
            type,
            startDate,
            endDate,
            page = 1,
            limit = 10
        } = req.query;

        const query = {
            patient: req.params.patientId,
            doctor: req.user._id
        };

        if (type) {
            query.type = type;
        }

        if (startDate && endDate) {
            query.createdAt = {
                $gte: new Date(startDate),
                $lte: new Date(endDate)
            };
        }

        const skip = (page - 1) * limit;

        const entries = await Charting.find(query)
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .populate('appointment', 'date type');

        const total = await Charting.countDocuments(query);

        res.json({
            entries,
            total,
            pages: Math.ceil(total / limit),
            currentPage: page
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get single charting entry
router.get('/:id', auth, async (req, res) => {
    try {
        const entry = await Charting.findOne({
            _id: req.params.id,
            doctor: req.user._id
        }).populate('appointment', 'date type');

        if (!entry) {
            return res.status(404).json({ message: 'Charting entry not found' });
        }

        res.json(entry);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Create new charting entry
router.post('/', auth, [
    body('patient').isMongoId().withMessage('Valid patient ID is required'),
    body('type').isIn(['progress-note', 'consultation', 'procedure', 'discharge', 'admission']).withMessage('Valid entry type is required'),
    body('template').optional().isIn(['general', 'surgery', 'dermatology', 'cardiology', 'pediatrics', 'custom']),
    body('appointment').optional().isMongoId(),
    body('subjective').optional().isObject(),
    body('objective').optional().isObject(),
    body('assessment').optional().isObject(),
    body('orders').optional().isArray()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const entry = new Charting({
            ...req.body,
            doctor: req.user._id
        });

        await entry.save();
        res.status(201).json(entry);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Update charting entry
router.put('/:id', auth, [
    body('subjective').optional().isObject(),
    body('objective').optional().isObject(),
    body('assessment').optional().isObject(),
    body('orders').optional().isArray(),
    body('status').optional().isIn(['draft', 'final', 'signed', 'amended'])
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const entry = await Charting.findOne({
            _id: req.params.id,
            doctor: req.user._id,
            status: { $ne: 'signed' }
        });

        if (!entry) {
            return res.status(404).json({ message: 'Charting entry not found or already signed' });
        }

        Object.keys(req.body).forEach(key => {
            if (req.body[key] !== undefined) {
                entry[key] = req.body[key];
            }
        });

        await entry.save();
        res.json(entry);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add amendment to charting entry
router.post('/:id/amendments', auth, [
    body('content').trim().notEmpty().withMessage('Amendment content is required')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const entry = await Charting.findOne({
            _id: req.params.id,
            doctor: req.user._id
        });

        if (!entry) {
            return res.status(404).json({ message: 'Charting entry not found' });
        }

        entry.amendments.push({
            content: req.body.content,
            doctor: req.user._id
        });

        entry.status = 'amended';
        await entry.save();
        res.json(entry);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add voice note to charting entry
router.post('/:id/voice-notes', auth, [
    body('url').trim().notEmpty().withMessage('Voice note URL is required'),
    body('duration').isInt({ min: 1 }).withMessage('Valid duration is required'),
    body('transcription').optional().trim()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const entry = await Charting.findOne({
            _id: req.params.id,
            doctor: req.user._id
        });

        if (!entry) {
            return res.status(404).json({ message: 'Charting entry not found' });
        }

        entry.voiceNotes.push({
            ...req.body,
            date: new Date()
        });

        await entry.save();
        res.json(entry);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add attachment to charting entry
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

        const entry = await Charting.findOne({
            _id: req.params.id,
            doctor: req.user._id
        });

        if (!entry) {
            return res.status(404).json({ message: 'Charting entry not found' });
        }

        entry.attachments.push({
            ...req.body,
            uploadedBy: req.user._id
        });

        await entry.save();
        res.json(entry);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get charting templates
router.get('/templates/:specialty', auth, async (req, res) => {
    try {
        // In a real application, this would fetch templates from a database
        // For now, we'll return a mock template based on the specialty
        const templates = {
            surgery: {
                subjective: {
                    chiefComplaint: '',
                    historyOfPresentIllness: '',
                    reviewOfSystems: {
                        general: '',
                        cardiovascular: '',
                        respiratory: '',
                        gastrointestinal: '',
                        musculoskeletal: '',
                        neurological: '',
                        psychiatric: '',
                        other: ''
                    }
                },
                objective: {
                    vitalSigns: {
                        temperature: null,
                        bloodPressure: { systolic: null, diastolic: null },
                        heartRate: null,
                        respiratoryRate: null,
                        oxygenSaturation: null,
                        painScore: null
                    },
                    physicalExam: {
                        general: '',
                        head: '',
                        eyes: '',
                        ears: '',
                        nose: '',
                        throat: '',
                        neck: '',
                        chest: '',
                        heart: '',
                        abdomen: '',
                        extremities: '',
                        neurological: '',
                        skin: ''
                    }
                },
                assessment: {
                    diagnosis: [],
                    plan: [],
                    followUp: {
                        date: null,
                        instructions: ''
                    }
                }
            }
            // Add more specialty templates as needed
        };

        const template = templates[req.params.specialty] || templates.surgery;
        res.json(template);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router; 