// Funciones adicionales para aplicaciones

// Aplicación de facturas
const InvoiceApp = {
    init: function() {
        this.loadInvoices();
        this.setupEventListeners();
    },
    
    loadInvoices: function() {
        // Cargar facturas pendientes por defecto
        this.loadPendingInvoices();
    },
    
    loadPendingInvoices: function() {
        fetch('https://mechanicsystem/getInvoices', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: 'pending' })
        })
        .then(response => response.json())
        .then(invoices => {
            this.displayInvoices(invoices, 'pending');
        });
    },
    
    loadClaimedInvoices: function() {
        fetch('https://mechanicsystem/getInvoices', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: 'claimed' })
        })
        .then(response => response.json())
        .then(invoices => {
            this.displayInvoices(invoices, 'claimed');
        });
    },
    
    displayInvoices: function(invoices, status) {
        const container = document.getElementById('invoicesList');
        container.innerHTML = '';
        
        if (invoices.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-receipt"></i>
                    <p>No hay facturas ${status === 'pending' ? 'pendientes' : 'reclamadas'}</p>
                </div>
            `;
            return;
        }
        
        invoices.forEach(invoice => {
            const invoiceElement = this.createInvoiceElement(invoice);
            container.appendChild(invoiceElement);
        });
    },
    
    createInvoiceElement: function(invoice) {
        const div = document.createElement('div');
        div.className = 'invoice-item';
        div.dataset.id = invoice.id;
        
        const statusClass = `status-${invoice.status}`;
        const statusText = getStatusText(invoice.status);
        const vehicleName = getVehicleName(invoice.vehicle_model);
        
        div.innerHTML = `
            <div class="invoice-header">
                <div class="invoice-info">
                    <div class="invoice-vehicle">${vehicleName}</div>
                    <div class="invoice-plate">${invoice.vehicle_plate}</div>
                </div>
                <div class="invoice-status ${statusClass}">${statusText}</div>
            </div>
            <div class="invoice-body">
                <div class="invoice-customer">
                    <i class="fas fa-user"></i>
                    <span>${invoice.customer_name}</span>
                </div>
                <div class="invoice-amount">
                    <i class="fas fa-dollar-sign"></i>
                    <span>$${invoice.amount}</span>
                </div>
                <div class="invoice-date">
                    <i class="fas fa-calendar"></i>
                    <span>${formatDate(invoice.created_at)}</span>
                </div>
            </div>
            <div class="invoice-actions">
                ${invoice.status === 'pending' ? 
                    `<button class="btn-primary btn-sm" onclick="claimInvoice(${invoice.id})">
                        <i class="fas fa-hand-paper"></i> Reclamar
                    </button>` : 
                    invoice.status === 'claimed' ?
                    `<button class="btn-success btn-sm" onclick="completeInvoice(${invoice.id})">
                        <i class="fas fa-check"></i> Completar
                    </button>` : ''
                }
                <button class="btn-secondary btn-sm" onclick="viewInvoiceDetails(${invoice.id})">
                    <i class="fas fa-eye"></i> Ver
                </button>
            </div>
        `;
        
        return div;
    },
    
    setupEventListeners: function() {
        // Filtros de estado
        document.querySelectorAll('.invoice-filter').forEach(button => {
            button.addEventListener('click', (e) => {
                const status = e.target.dataset.status;
                document.querySelectorAll('.invoice-filter').forEach(btn => {
                    btn.classList.remove('active');
                });
                e.target.classList.add('active');
                
                if (status === 'pending') {
                    this.loadPendingInvoices();
                } else if (status === 'claimed') {
                    this.loadClaimedInvoices();
                }
            });
        });
    }
};

// Aplicación de miembros
const MembersApp = {
    init: function() {
        this.loadMembers();
        this.setupChat();
    },
    
    loadMembers: function() {
        fetch('https://mechanicsystem/getMembers')
            .then(response => response.json())
            .then(members => {
                this.displayMembers(members);
                this.displayTopList(members);
            });
    },
    
    displayMembers: function(members) {
        const container = document.getElementById('membersList');
        container.innerHTML = '';
        
        members.forEach(member => {
            const memberElement = this.createMemberElement(member);
            container.appendChild(memberElement);
        });
    },
    
    createMemberElement: function(member) {
        const div = document.createElement('div');
        div.className = 'member-item';
        
        const rankText = getRankText(member.rank);
        const rankClass = `rank-${member.rank}`;
        
        div.innerHTML = `
            <div class="member-header">
                <div class="member-avatar">
                    <div class="avatar">${member.member_name.charAt(0)}</div>
                    <div class="member-info">
                        <div class="member-name">${member.member_name}</div>
                        <div class="member-rank ${rankClass}">${rankText}</div>
                    </div>
                </div>
                <div class="member-actions">
                    ${currentBusiness && currentBusiness.rank === 'boss' ? `
                        <button class="btn-icon" onclick="editMemberRank('${member.member_identifier}')">
                            <i class="fas fa-edit"></i>
                        </button>
                        ${member.rank !== 'boss' ? `
                            <button class="btn-icon btn-danger" onclick="removeMember('${member.member_identifier}')">
                                <i class="fas fa-trash"></i>
                            </button>
                        ` : ''}
                    ` : ''}
                </div>
            </div>
            <div class="member-stats">
                <div class="stat">
                    <div class="stat-label">Facturas</div>
                    <div class="stat-value">${member.completed_invoices}</div>
                </div>
                <div class="stat">
                    <div class="stat-label">Ganado</div>
                    <div class="stat-value">$${member.total_earned}</div>
                </div>
                <div class="stat">
                    <div class="stat-label">Miembro desde</div>
                    <div class="stat-value">${formatDate(member.joined_at)}</div>
                </div>
            </div>
        `;
        
        return div;
    },
    
    displayTopList: function(members) {
        const sorted = [...members].sort((a, b) => b.completed_invoices - a.completed_invoices);
        const container = document.getElementById('topList');
        container.innerHTML = '';
        
        sorted.forEach((member, index) => {
            const topElement = document.createElement('div');
            topElement.className = 'top-item';
            
            // Medalla según posición
            let medal = '';
            if (index === 0) medal = '<i class="fas fa-crown" style="color: gold;"></i>';
            else if (index === 1) medal = '<i class="fas fa-medal" style="color: silver;"></i>';
            else if (index === 2) medal = '<i class="fas fa-medal" style="color: #cd7f32;"></i>';
            
            topElement.innerHTML = `
                <div class="top-position">
                    <span class="position-number">#${index + 1}</span>
                    ${medal}
                </div>
                <div class="top-member">
                    <div class="avatar small">${member.member_name.charAt(0)}</div>
                    <div class="top-info">
                        <div class="top-name">${member.member_name}</div>
                        <div class="top-rank rank-${member.rank}">${getRankText(member.rank)}</div>
                    </div>
                </div>
                <div class="top-stats">
                    <div class="top-stat">
                        <i class="fas fa-trophy"></i>
                        <span>${member.completed_invoices}</span>
                    </div>
                    <div class="top-stat">
                        <i class="fas fa-money-bill-wave"></i>
                        <span>$${member.total_earned}</span>
                    </div>
                </div>
            `;
            
            container.appendChild(topElement);
        });
    },
    
    setupChat: function() {
        const chatInput = document.getElementById('chatInput');
        const sendButton = document.querySelector('.chat-input button');
        
        const sendMessage = () => {
            const message = chatInput.value.trim();
            if (message) {
                fetch('https://mechanicsystem/sendMessage', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ message: message })
                });
                chatInput.value = '';
            }
        };
        
        sendButton.addEventListener('click', sendMessage);
        chatInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                sendMessage();
            }
        });
    }
};

// Aplicación de banco
const BankApp = {
    init: function() {
        this.loadBalance();
        this.loadTransactions();
        this.setupEventListeners();
    },
    
    loadBalance: function() {
        if (currentBusiness) {
            document.getElementById('currentBalance').textContent = `$${currentBusiness.balance}`;
        }
    },
    
    loadTransactions: function(limit = 20) {
        fetch('https://mechanicsystem/getTransactions', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ limit: limit })
        })
        .then(response => response.json())
        .then(transactions => {
            this.displayTransactions(transactions);
        });
    },
    
    displayTransactions: function(transactions) {
        const container = document.getElementById('transactionsList');
        container.innerHTML = '';
        
        if (transactions.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-exchange-alt"></i>
                    <p>No hay transacciones registradas</p>
                </div>
            `;
            return;
        }
        
        transactions.forEach(transaction => {
            const transactionElement = this.createTransactionElement(transaction);
            container.appendChild(transactionElement);
        });
    },
    
    createTransactionElement: function(transaction) {
        const div = document.createElement('div');
        div.className = 'transaction-item';
        
        const typeInfo = this.getTransactionTypeInfo(transaction.transaction_type);
        const amountClass = transaction.amount > 0 ? 'positive' : 'negative';
        const amountSign = transaction.amount > 0 ? '+' : '';
        
        div.innerHTML = `
            <div class="transaction-header">
                <div class="transaction-type ${typeInfo.class}">
                    <i class="fas fa-${typeInfo.icon}"></i>
                    <span>${typeInfo.text}</span>
                </div>
                <div class="transaction-amount ${amountClass}">
                    ${amountSign}$${Math.abs(transaction.amount)}
                </div>
            </div>
            <div class="transaction-body">
                <div class="transaction-description">
                    ${transaction.description || 'Transacción'}
                </div>
                <div class="transaction-details">
                    <div class="transaction-date">
                        <i class="fas fa-calendar"></i>
                        <span>${formatDate(transaction.created_at)}</span>
                    </div>
                    <div class="transaction-time">
                        <i class="fas fa-clock"></i>
                        <span>${formatTime(transaction.created_at)}</span>
                    </div>
                </div>
            </div>
        `;
        
        return div;
    },
    
    getTransactionTypeInfo: function(type) {
        const types = {
            'deposit': { icon: 'arrow-down', text: 'Depósito', class: 'type-deposit' },
            'withdraw': { icon: 'arrow-up', text: 'Retiro', class: 'type-withdraw' },
            'invoice': { icon: 'receipt', text: 'Factura', class: 'type-invoice' },
            'salary': { icon: 'money-bill-wave', text: 'Salario', class: 'type-salary' }
        };
        return types[type] || { icon: 'exchange-alt', text: type, class: '' };
    },
    
    setupEventListeners: function() {
        const depositBtn = document.querySelector('.btn-deposit');
        const withdrawBtn = document.querySelector('.btn-withdraw');
        
        if (depositBtn) {
            depositBtn.addEventListener('click', () => {
                const amount = document.getElementById('depositAmount').value;
                if (amount && amount > 0) {
                    this.deposit(parseFloat(amount));
                }
            });
        }
        
        if (withdrawBtn) {
            withdrawBtn.addEventListener('click', () => {
                const amount = document.getElementById('withdrawAmount').value;
                if (amount && amount > 0) {
                    this.withdraw(parseFloat(amount));
                }
            });
        }
    },
    
    deposit: function(amount) {
        fetch('https://mechanicsystem/depositMoney', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ amount: amount })
        })
        .then(() => {
            this.loadBalance();
            this.loadTransactions();
            document.getElementById('depositAmount').value = '';
            showNotification(`Depositado $${amount}`, 'success');
        });
    },
    
    withdraw: function(amount) {
        fetch('https://mechanicsystem/withdrawMoney', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ amount: amount })
        })
        .then(() => {
            this.loadBalance();
            this.loadTransactions();
            document.getElementById('withdrawAmount').value = '';
            showNotification(`Retirado $${amount}`, 'success');
        });
    }
};

// Aplicación de pagos
const PaymentsApp = {
    init: function() {
        this.loadPayments();
    },
    
    loadPayments: function() {
        fetch('https://mechanicsystem/getPayments')
            .then(response => response.json())
            .then(payments => {
                this.displayPayments(payments);
            });
    },
    
    displayPayments: function(payments) {
        const container = document.getElementById('paymentsList');
        container.innerHTML = '';
        
        for (const [rank, amount] of Object.entries(payments)) {
            const paymentElement = this.createPaymentElement(rank, amount);
            container.appendChild(paymentElement);
        }
    },
    
    createPaymentElement: function(rank, amount) {
        const div = document.createElement('div');
        div.className = 'payment-item';
        
        const rankText = getRankText(rank);
        const canEdit = currentBusiness && currentBusiness.rank === 'boss';
        
        div.innerHTML = `
            <div class="payment-header">
                <div class="payment-info">
                    <div class="payment-rank">${rankText}</div>
                    <div class="payment-current">Actual: $${amount}/día</div>
                </div>
                <div class="payment-default">
                    <small>Por defecto: $${Config.DefaultDailyPay[rank]}/día</small>
                </div>
            </div>
            ${canEdit ? `
            <div class="payment-edit">
                <input type="number" 
                       id="edit_${rank}" 
                       value="${amount}" 
                       min="0" 
                       max="10000" 
                       step="50"
                       placeholder="Nuevo monto">
                <button class="btn-primary" onclick="updatePayment('${rank}')">
                    <i class="fas fa-save"></i> Actualizar
                </button>
                <button class="btn-secondary" onclick="resetPayment('${rank}')">
                    <i class="fas fa-undo"></i> Restaurar
                </button>
            </div>
            ` : ''}
        `;
        
        return div;
    }
};

// Funciones globales para aplicaciones
function viewInvoiceDetails(invoiceId) {
    fetch('https://mechanicsystem/getInvoiceDetails', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ invoiceId: invoiceId })
    })
    .then(response => response.json())
    .then(invoice => {
        showInvoiceModal(invoice);
    });
}

function showInvoiceModal(invoice) {
    const modal = document.getElementById('invoiceModal');
    const content = document.getElementById('invoiceDetails');
    
    let customizationHtml = '';
    if (invoice.customization) {
        customizationHtml = `
            <div class="modal-section">
                <h4>Personalización</h4>
                <div class="customization-grid">
        `;
        
        for (const [key, value] of Object.entries(invoice.customization)) {
            if (value !== null && value !== '' && value !== undefined) {
                customizationHtml += `
                    <div class="customization-item">
                        <span class="customization-key">${key}:</span>
                        <span class="customization-value">${value}</span>
                    </div>
                `;
            }
        }
        
        customizationHtml += `
                </div>
            </div>
        `;
    }
    
    content.innerHTML = `
        <div class="modal-section">
            <h4>Información General</h4>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Cliente:</span>
                    <span class="info-value">${invoice.customer_name}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Vehículo:</span>
                    <span class="info-value">${getVehicleName(invoice.vehicle_model)}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Placa:</span>
                    <span class="info-value">${invoice.vehicle_plate}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Monto:</span>
                    <span class="info-value">$${invoice.amount}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Estado:</span>
                    <span class="info-value status-${invoice.status}">${getStatusText(invoice.status)}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Fecha:</span>
                    <span class="info-value">${formatDate(invoice.created_at)}</span>
                </div>
            </div>
        </div>
        ${customizationHtml}
    `;
    
    // Configurar botones de acción
    const actions = document.getElementById('invoiceActions');
    actions.innerHTML = '';
    
    if (invoice.status === 'pending') {
        actions.innerHTML = `
            <button class="btn-primary" onclick="claimInvoice(${invoice.id})">
                <i class="fas fa-hand-paper"></i> Reclamar Factura
            </button>
        `;
    } else if (invoice.status === 'claimed') {
        actions.innerHTML = `
            <button class="btn-success" onclick="completeInvoice(${invoice.id})">
                <i class="fas fa-check"></i> Completar Trabajo
            </button>
        `;
    }
    
    modal.classList.add('active');
}

function editMemberRank(memberIdentifier) {
    const input = lib.inputDialog('Cambiar Rango', {
        type: 'select',
        label: 'Nuevo Rango',
        options: [
            { value: 'recruit', label: 'Recluta' },
            { value: 'employee', label: 'Empleado' },
            { value: 'manager', label: 'Gerente' }
        ],
        required: true
    });
    
    if (input) {
        fetch('https://mechanicsystem/changeMemberRank', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                memberIdentifier: memberIdentifier,
                newRank: input 
            })
        })
        .then(() => {
            MembersApp.loadMembers();
            showNotification('Rango actualizado', 'success');
        });
    }
}

function removeMember(memberIdentifier) {
    const confirm = lib.alertDialog({
        header: 'Eliminar Miembro',
        content: '¿Estás seguro de que quieres eliminar a este miembro?',
        centered: true,
        cancel: true
    });
    
    if (confirm === 'confirm') {
        fetch('https://mechanicsystem/removeMember', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ memberIdentifier: memberIdentifier })
        })
        .then(() => {
            MembersApp.loadMembers();
            showNotification('Miembro eliminado', 'success');
        });
    }
}

function updatePayment(rank) {
    const input = document.getElementById(`edit_${rank}`);
    const amount = input.value;
    
    if (amount && amount >= 0) {
        fetch('https://mechanicsystem/updatePayment', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ rank: rank, amount: parseFloat(amount) })
        })
        .then(() => {
            showNotification('Pago actualizado', 'success');
            PaymentsApp.loadPayments();
        });
    }
}

function resetPayment(rank) {
    const defaultAmount = Config.DefaultDailyPay[rank];
    fetch('https://mechanicsystem/updatePayment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rank: rank, amount: defaultAmount })
    })
    .then(() => {
        showNotification('Pago restaurado', 'success');
        PaymentsApp.loadPayments();
    });
}

// Funciones de utilidad adicionales
function showNotification(message, type = 'info') {
    // Crear notificación flotante
    const notification = document.createElement('div');
    notification.className = `floating-notification notification-${type}`;
    notification.innerHTML = `
        <div class="notification-content">
            <i class="fas fa-${getNotificationIcon(type)}"></i>
            <span>${message}</span>
        </div>
    `;
    
    document.body.appendChild(notification);
    
    // Remover después de 3 segundos
    setTimeout(() => {
        notification.style.animation = 'slideInRight 0.3s ease reverse';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}

function getNotificationIcon(type) {
    const icons = {
        'info': 'info-circle',
        'success': 'check-circle',
        'warning': 'exclamation-triangle',
        'error': 'times-circle'
    };
    return icons[type] || 'info-circle';
}

// Inicializar aplicaciones cuando se cargue la tablet
document.addEventListener('DOMContentLoaded', function() {
    // Las aplicaciones se inicializan cuando se abren sus respectivas pantallas
    console.log('Aplicaciones cargadas');
});

// Exportar para uso global
window.InvoiceApp = InvoiceApp;
window.MembersApp = MembersApp;
window.BankApp = BankApp;
window.PaymentsApp = PaymentsApp;