const mongoose = require('mongoose');

const chartingSchema = new mongoose.Schema({
    patient: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Patient',
        required: true
    },
    doctor: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    appointment: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Appointment'
    },
    type: {
        type: String,
        enum: ['progress-note', 'consultation', 'procedure', 'discharge', 'admission'],
        required: true
    },
    template: {
        type: String,
        enum: ['general', 'surgery', 'dermatology', 'cardiology', 'pediatrics', 'custom'],
        default: 'general'
    },
    subjective: {
        chiefComplaint: String,
        historyOfPresentIllness: String,
        reviewOfSystems: {
            general: String,
            cardiovascular: String,
            respiratory: String,
            gastrointestinal: String,
            musculoskeletal: String,
            neurological: String,
            psychiatric: String,
            other: String
        },
        pastMedicalHistory: String,
        familyHistory: String,
        socialHistory: String,
        medications: [{
            name: String,
            dosage: String,
            frequency: String
        }],
        allergies: [{
            allergen: String,
            reaction: String
        }]
    },
    objective: {
        vitalSigns: {
            temperature: Number,
            bloodPressure: {
                systolic: Number,
                diastolic: Number,
                unit: {
                    type: String,
                    enum: ['mmHg'],
                    default: 'mmHg'
                }
            },
            heartRate: Number,
            respiratoryRate: Number,
            oxygenSaturation: Number,
            painScore: Number
        },
        physicalExam: {
            general: String,
            head: String,
            eyes: String,
            ears: String,
            nose: String,
            throat: String,
            neck: String,
            chest: String,
            heart: String,
            abdomen: String,
            extremities: String,
            neurological: String,
            skin: String
        },
        labs: [{
            name: String,
            value: String,
            unit: String,
            referenceRange: String,
            date: Date
        }],
        imaging: [{
            type: String,
            findings: String,
            date: Date,
            url: String
        }]
    },
    assessment: {
        diagnosis: [{
            code: String,
            description: String,
            type: {
                type: String,
                enum: ['primary', 'secondary', 'differential'],
                default: 'primary'
            }
        }],
        plan: [{
            category: String,
            items: [String]
        }],
        followUp: {
            date: Date,
            instructions: String
        }
    },
    orders: [{
        type: {
            type: String,
            enum: ['medication', 'lab', 'imaging', 'procedure', 'referral', 'other'],
            required: true
        },
        name: String,
        details: String,
        status: {
            type: String,
            enum: ['pending', 'ordered', 'completed', 'cancelled'],
            default: 'pending'
        },
        date: {
            type: Date,
            default: Date.now
        }
    }],
    attachments: [{
        title: String,
        type: String,
        url: String,
        uploadDate: {
            type: Date,
            default: Date.now
        },
        uploadedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        }
    }],
    voiceNotes: [{
        url: String,
        duration: Number,
        transcription: String,
        date: {
            type: Date,
            default: Date.now
        }
    }],
    status: {
        type: String,
        enum: ['draft', 'final', 'signed', 'amended'],
        default: 'draft'
    },
    signature: {
        date: Date,
        doctor: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        }
    },
    amendments: [{
        content: String,
        date: {
            type: Date,
            default: Date.now
        },
        doctor: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        }
    }]
}, {
    timestamps: true
});

// Indexes for better query performance
chartingSchema.index({ patient: 1 });
chartingSchema.index({ doctor: 1 });
chartingSchema.index({ appointment: 1 });
chartingSchema.index({ type: 1 });
chartingSchema.index({ createdAt: -1 });

// Pre-save middleware to handle status changes
chartingSchema.pre('save', function(next) {
    if (this.isModified('status') && this.status === 'signed') {
        this.signature = {
            date: new Date(),
            doctor: this.doctor
        };
    }
    next();
});

const Charting = mongoose.model('Charting', chartingSchema);

module.exports = Charting; 