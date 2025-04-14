const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
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
    date: {
        type: Date,
        required: true
    },
    duration: {
        type: Number, // in minutes
        required: true,
        default: 30
    },
    type: {
        type: String,
        enum: ['initial', 'follow-up', 'consultation', 'emergency', 'routine', 'procedure'],
        required: true
    },
    status: {
        type: String,
        enum: ['scheduled', 'confirmed', 'completed', 'cancelled', 'no-show'],
        default: 'scheduled'
    },
    location: {
        type: String,
        required: true
    },
    notes: {
        type: String,
        trim: true
    },
    symptoms: [{
        type: String,
        trim: true
    }],
    diagnosis: {
        type: String,
        trim: true
    },
    treatment: {
        type: String,
        trim: true
    },
    followUpDate: {
        type: Date
    },
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
    reminders: [{
        type: {
            type: String,
            enum: ['email', 'sms', 'push'],
            required: true
        },
        time: {
            type: Number, // minutes before appointment
            required: true
        },
        sent: {
            type: Boolean,
            default: false
        }
    }],
    recurring: {
        isRecurring: {
            type: Boolean,
            default: false
        },
        frequency: {
            type: String,
            enum: ['daily', 'weekly', 'monthly', 'yearly']
        },
        endDate: Date,
        daysOfWeek: [{
            type: Number, // 0-6 for Sunday-Saturday
        }]
    }
}, {
    timestamps: true
});

// Indexes for better query performance
appointmentSchema.index({ date: 1 });
appointmentSchema.index({ patient: 1 });
appointmentSchema.index({ doctor: 1 });
appointmentSchema.index({ status: 1 });

// Virtual for end time
appointmentSchema.virtual('endTime').get(function() {
    return new Date(this.date.getTime() + this.duration * 60000);
});

// Method to check for conflicts
appointmentSchema.methods.hasConflict = async function() {
    const Appointment = mongoose.model('Appointment');
    const existingAppointment = await Appointment.findOne({
        doctor: this.doctor,
        date: {
            $lt: this.endTime,
            $gt: this.date
        },
        status: { $ne: 'cancelled' },
        _id: { $ne: this._id }
    });
    return !!existingAppointment;
};

// Pre-save middleware to check for conflicts
appointmentSchema.pre('save', async function(next) {
    if (this.isNew || this.isModified('date') || this.isModified('duration')) {
        const hasConflict = await this.hasConflict();
        if (hasConflict) {
            next(new Error('Appointment time conflicts with existing appointment'));
            return;
        }
    }
    next();
});

const Appointment = mongoose.model('Appointment', appointmentSchema);

module.exports = Appointment; 