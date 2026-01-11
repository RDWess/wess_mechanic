// Variables globales
let currentScreen = 'home';
let currentBusiness = null;
let pendingInvoices = [];
let businessMembers = [];
let chatMessages = [];
let currentWorkHUD = null;

// Inicializar cuando se carga la página
window.addEventListener('DOMContentLoaded', function() {
    updateTime();
    setInterval(updateTime, 60000);
    
    // Escuchar mensajes NUI
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        switch(data.action) {
            case 'openTablet':
                openTablet(data.business, data.apps);
                break;
                
            case 'updateBusinessInfo':
                updateBusinessInfo(data.data);
                break;
                
            case 'openInvoices':
                showInvoices(data.invoices);
                break;
                
            case 'openMembers':
                showMembers(data.members);
                break;
                
            case 'openBank':
                showBank(data.business);
                break;
                
            case 'openPayments':
                showPayments(data.defaultPayments);
                break;
                
            case 'showWorkHUD':
                showWorkHUD(data.invoice);
                break;
                
            case 'hideWorkHUD':
                hideWorkHUD();
                break;
                
            case 'receiveChatMessage':
                receiveChatMessage(data.message);
                break;
                
            case 'closeTablet':
                closeTablet();
                break;
        }
    });
});

// Actualizar hora
function updateTime() {
    const now = new Date();
    const timeString = now.toLocaleTimeString('es-ES', { 
        hour: '2-digit', 
        minute: '2-digit' 
    });
    document.getElementById('currentTime').textContent = timeString;
}

// Abrir tablet
function openTablet(business, apps) {
    currentBusiness = business;
    document.getElementById('businessName').textContent = business.name;
    document.getElementById('playerName').textContent = business.rank;
    
    // Cargar apps
    loadApps(apps);
    
    // Mostrar pantalla principal
    showScreen('home');
}

// Cargar aplicaciones
function loadApps(apps) {
    const container = document.getElementById('appsContainer');
    container.innerHTML = '';
    
    apps.forEach(app => {
        const appElement = document.createElement('div');
        appElement.className = 'app';
        appElement.style.borderColor = app.color;
        appElement.onclick = () => openApp(app.id);
        
        appElement.innerHTML = `
            <i class="fas fa-${app.icon}" style="color: ${app.color}"></i>
            <span>${app.label}</span>
        `;
        
        container.appendChild(appElement);
    });
}

// Mostrar pantalla
function showScreen(screenId) {
    // Ocultar todas las pantallas
    document.querySelectorAll('.screen').forEach(screen => {
        screen.classList.remove('active');
    });
    
    // Mostrar pantalla solicitada
    document.getElementById(screenId + 'Screen').classList.add('active');
    currentScreen = screenId;
}

// Volver atrás
function goBack() {
    showScreen('home');
}

// Abrir aplicación
function openApp(appId) {
    switch(appId) {
        case 'facturas':
            showScreen('invoices');
            fetch('https://mechanicsystem/getInvoices', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ status: 'pending' })
            }).then(response => response.json())
              .then(invoices => showInvoices(invoices));
            break;
            
        case 'miembros':
            showScreen('members');
            fetch('https://mechanicsystem/getMembers')
                .then(response => response.json())
                .then(members => showMembers(members));
            break;
            
        case 'banco':
            showScreen('bank');
            if (currentBusiness) {
                updateBankInfo();
            }
            break;
            
        case 'pagos':
            showScreen('payments');
            fetch('https://mechanicsystem/getPayments')
                .then(response => response.json())
                .then(payments => showPayments(payments));
            break;
            
        default:
            // Para otras apps, usar NUI
            fetch('https://mechanicsystem/openApp', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ appId: appId })
            });
            break;
    }
}

// Mostrar facturas
function showInvoices(invoices) {
    pendingInvoices = invoices;
    const container = document.getElementById('invoicesList');
    container.innerHTML = '';
    
    if (invoices.length === 0) {
        container.innerHTML = '<div class="empty-state">No hay facturas pendientes</div>';
        return;
    }
    
    invoices.forEach(invoice => {
        const invoiceElement = document.createElement('div');
        invoiceElement.className = 'invoice-item';
        invoiceElement.onclick = () => showInvoiceDetails(invoice);
        
        invoiceElement.innerHTML = `
            <div class="invoice-header">
                <div class="invoice-vehicle">${getVehicleName(invoice.vehicle_model)}</div>
                <div class="invoice-status status-${invoice.status}">
                    ${getStatusText(invoice.status)}
                </div>
            </div>
            <div class="invoice-details">
                <div class="detail">
                    <i class="fas fa-user"></i>
                    <span>${invoice.customer_name}</span>
                </div>
                <div class="detail">
                    <i class="fas fa-dollar-sign"></i>
                    <span>$${invoice.amount}</span>
                </div>
                <div class="detail">
                    <i class="fas fa-clock"></i>
                    <span>${formatTime(invoice.created_at)}</span>
                </div>
            </div>
        `;
        
        container.appendChild(invoiceElement);
    });
}

// Mostrar detalles de factura
function showInvoiceDetails(invoice) {
    const container = document.getElementById('invoiceDetails');
    
    let customizationList = '';
    if (invoice.customization) {
        for (const [key, value] of Object.entries(invoice.customization)) {
            if (value !== null && value !== undefined && value !== '') {
                customizationList += `<div class="customization-item">
                    <span>${key}:</span>
                    <span>${value}</span>
                </div>`;
            }
        }
    }
    
    container.innerHTML = `
        <div class="invoice-detail-section">
            <h4>Información del Cliente</h4>
            <p><strong>Nombre:</strong> ${invoice.customer_name}</p>
            <p><strong>Vehículo:</strong> ${getVehicleName(invoice.vehicle_model)}</p>
            <p><strong>Placa:</strong> ${invoice.vehicle_plate}</p>
        </div>
        
        <div class="invoice-detail-section">
            <h4>Detalles de la Factura</h4>
            <p><strong>Monto:</strong> $${invoice.amount}</p>
            <p><strong>Estado:</strong> ${getStatusText(invoice.status)}</p>
            <p><strong>Fecha:</strong> ${formatDate(invoice.created_at)}</p>
        </div>
        
        ${customizationList ? `
        <div class="invoice-detail-section">
            <h4>Personalización</h4>
            <div class="customization-list">${customizationList}</div>
        </div>
        ` : ''}
    `;
    
    // Configurar botón de reclamar
    const claimBtn = document.getElementById('claimInvoiceBtn');
    if (invoice.status === 'pending') {
        claimBtn.style.display = 'block';
        claimBtn.onclick = () => claimInvoice(invoice.id);
        claimBtn.textContent = 'Reclamar Factura';
    } else if (invoice.status === 'claimed') {
        claimBtn.style.display = 'block';
        claimBtn.onclick = () => completeInvoice(invoice.id);
        claimBtn.textContent = 'Completar Trabajo';
        claimBtn.className = 'btn-success';
    } else {
        claimBtn.style.display = 'none';
    }
    
    // Mostrar modal
    showModal('invoiceModal');
}

// Mostrar miembros
function showMembers(members) {
    businessMembers = members;
    const container = document.getElementById('membersList');
    container.innerHTML = '';
    
    members.forEach(member => {
        const memberElement = document.createElement('div');
        memberElement.className = 'member-item';
        
        memberElement.innerHTML = `
            <div class="member-header">
                <div class="member-name">${member.member_name}</div>
                <div class="member-rank rank-${member.rank}">
                    ${getRankText(member.rank)}
                </div>
            </div>
            <div class="member-stats">
                <div class="stat">
                    <i class="fas fa-receipt"></i>
                    <span>${member.completed_invoices} facturas</span>
                </div>
                <div class="stat">
                    <i class="fas fa-dollar-sign"></i>
                    <span>$${member.total_earned}</span>
                </div>
                <div class="stat">
                    <i class="fas fa-calendar"></i>
                    <span>${formatDate(member.joined_at)}</span>
                </div>
            </div>
        `;
        
        container.appendChild(memberElement);
    });
    
    // Actualizar top
    updateTopList(members);
}

// Actualizar lista top
function updateTopList(members) {
    const sortedMembers = [...members].sort((a, b) => b.completed_invoices - a.completed_invoices);
    const container = document.getElementById('topList');
    container.innerHTML = '';
    
    sortedMembers.forEach((member, index) => {
        const topElement = document.createElement('div');
        topElement.className = 'top-item';
        
        topElement.innerHTML = `
            <div class="top-header">
                <div class="top-position">#${index + 1}</div>
                <div class="top-name">${member.member_name}</div>
                <div class="top-rank">${getRankText(member.rank)}</div>
            </div>
            <div class="top-stats">
                <div class="stat">
                    <i class="fas fa-trophy"></i>
                    <span>${member.completed_invoices} facturas completadas</span>
                </div>
                <div class="stat">
                    <i class="fas fa-money-bill-wave"></i>
                    <span>$${member.total_earned} ganados</span>
                </div>
            </div>
        `;
        
        container.appendChild(topElement);
    });
}

// Mostrar información del banco
function updateBankInfo() {
    if (!currentBusiness) return;
    
    document.getElementById('currentBalance').textContent = `$${currentBusiness.balance}`;
    
    // Obtener transacciones
    fetch('https://mechanicsystem/getTransactions')
        .then(response => response.json())
        .then(transactions => showTransactions(transactions));
}

// Mostrar transacciones
function showTransactions(transactions) {
    const container = document.getElementById('transactionsList');
    container.innerHTML = '';
    
    transactions.forEach(transaction => {
        const transactionElement = document.createElement('div');
        transactionElement.className = 'transaction-item';
        
        const typeIcon = transaction.transaction_type === 'deposit' ? 'arrow-down' : 
                        transaction.transaction_type === 'withdraw' ? 'arrow-up' : 'exchange-alt';
        const typeColor = transaction.transaction_type === 'deposit' ? 'success' : 
                         transaction.transaction_type === 'withdraw' ? 'warning' : 'info';
        
        transactionElement.innerHTML = `
            <div class="transaction-header">
                <div class="transaction-type type-${typeColor}">
                    <i class="fas fa-${typeIcon}"></i>
                    ${getTransactionTypeText(transaction.transaction_type)}
                </div>
                <div class="transaction-amount ${transaction.amount > 0 ? 'positive' : 'negative'}">
                    ${transaction.amount > 0 ? '+' : ''}$${Math.abs(transaction.amount)}
                </div>
            </div>
            <div class="transaction-details">
                <p>${transaction.description || 'Sin descripción'}</p>
                <small>${formatTime(transaction.created_at)}</small>
            </div>
        `;
        
        container.appendChild(transactionElement);
    });
}

// Mostrar pagos
function showPayments(payments) {
    const container = document.getElementById('paymentsList');
    container.innerHTML = '';
    
    for (const [rank, amount] of Object.entries(payments)) {
        const paymentElement = document.createElement('div');
        paymentElement.className = 'payment-item';
        
        paymentElement.innerHTML = `
            <div class="payment-header">
                <div class="payment-rank">${getRankText(rank)}</div>
                <div class="payment-amount">$${amount}/día</div>
            </div>
            <div class="payment-actions">
                <input type="number" id="edit_${rank}" value="${amount}" min="0" max="10000">
                <button class="btn-primary" onclick="updatePayment('${rank}')">
                    <i class="fas fa-save"></i> Actualizar
                </button>
            </div>
        `;
        
        container.appendChild(paymentElement);
    }
}

// Mostrar HUD de trabajo
function showWorkHUD(invoice) {
    currentWorkHUD = invoice;
    const hud = document.getElementById('workHUD');
    
    document.getElementById('hudVehicle').textContent = getVehicleName(invoice.vehicle_model);
    document.getElementById('hudCustomer').textContent = invoice.customer_name;
    document.getElementById('hudAmount').textContent = `$${invoice.amount}`;
    
    // Personalización
    const customizationContainer = document.getElementById('hudCustomization');
    customizationContainer.innerHTML = '';
    
    if (invoice.customization) {
        for (const [key, value] of Object.entries(invoice.customization)) {
            if (value !== null && value !== undefined && value !== '') {
                const item = document.createElement('div');
                item.className = 'customization-item';
                item.innerHTML = `<span>${key}:</span><span>${value}</span>`;
                customizationContainer.appendChild(item);
            }
        }
    }
    
    hud.classList.add('active');
}

// Ocultar HUD de trabajo
function hideWorkHUD() {
    document.getElementById('workHUD').classList.remove('active');
    currentWorkHUD = null;
}

// Completar trabajo actual
function completeWork() {
    if (currentWorkHUD) {
        fetch('https://mechanicsystem/completeInvoice', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ invoiceId: currentWorkHUD.id })
        });
    }
    hideWorkHUD();
}

// Cerrar HUD
function closeWorkHUD() {
    hideWorkHUD();
}

// Recibir mensaje de chat
function receiveChatMessage(message) {
    chatMessages.push(message);
    
    if (currentScreen === 'members') {
        const container = document.getElementById('chatMessages');
        const messageElement = document.createElement('div');
        messageElement.className = 'chat-message';
        
        messageElement.innerHTML = `
            <div class="message-header">
                <span class="message-sender">${message.sender}</span>
                <span class="message-time">${formatTime(new Date())}</span>
            </div>
            <div class="message-content">${message.message}</div>
        `;
        
        container.appendChild(messageElement);
        container.scrollTop = container.scrollHeight;
    }
}

// Enviar mensaje
function sendMessage() {
    const input = document.getElementById('chatInput');
    const message = input.value.trim();
    
    if (message) {
        fetch('https://mechanicsystem/sendMessage', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ message: message })
        });
        
        input.value = '';
    }
}

// Depositar dinero
function depositMoney() {
    const amount = document.getElementById('depositAmount').value;
    if (amount && amount > 0) {
        fetch('https://mechanicsystem/depositMoney', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ amount: parseFloat(amount) })
        });
        document.getElementById('depositAmount').value = '';
    }
}

// Retirar dinero
function withdrawMoney() {
    const amount = document.getElementById('withdrawAmount').value;
    if (amount && amount > 0) {
        fetch('https://mechanicsystem/withdrawMoney', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ amount: parseFloat(amount) })
        });
        document.getElementById('withdrawAmount').value = '';
    }
}

// Añadir miembro
function addMember() {
    showModal('addMemberModal');
}

// Confirmar añadir miembro
function confirmAddMember() {
    const rank = document.getElementById('memberRank').value;
    
    fetch('https://mechanicsystem/addMember', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rank: rank })
    });
    
    closeModal('addMemberModal');
}

// Actualizar pago
function updatePayment(rank) {
    const input = document.getElementById(`edit_${rank}`);
    const amount = input.value;
    
    fetch('https://mechanicsystem/updatePayment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rank: rank, amount: amount })
    });
}

// Reclamar factura
function claimInvoice(invoiceId) {
    fetch('https://mechanicsystem/claimInvoice', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ invoiceId: invoiceId })
    });
    closeModal('invoiceModal');
}

// Completar factura
function completeInvoice(invoiceId) {
    fetch('https://mechanicsystem/completeInvoice', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ invoiceId: invoiceId })
    });
    closeModal('invoiceModal');
}

// Mostrar modal
function showModal(modalId) {
    document.getElementById(modalId).classList.add('active');
}

// Cerrar modal
function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

// Cerrar tablet
function closeTablet() {
    fetch('https://mechanicsystem/closeTablet', { method: 'POST' });
}

// Cerrar sesión
function logout() {
    closeTablet();
}

// Cambiar pestaña
function switchTab(tabId, button) {
    // Desactivar todas las pestañas
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    
    // Activar pestaña seleccionada
    button.classList.add('active');
    document.getElementById(tabId + 'Tab').classList.add('active');
}

// Funciones de utilidad
function getVehicleName(modelHash) {
    // Esta función necesitaría un mapeo de hashes a nombres
    return "Vehículo #" + modelHash;
}

function getStatusText(status) {
    const statusTexts = {
        'pending': 'Pendiente',
        'claimed': 'Reclamada',
        'completed': 'Completada',
        'cancelled': 'Cancelada'
    };
    return statusTexts[status] || status;
}

function getRankText(rank) {
    const rankTexts = {
        'boss': 'Jefe',
        'manager': 'Gerente',
        'employee': 'Empleado',
        'recruit': 'Recluta'
    };
    return rankTexts[rank] || rank;
}

function getTransactionTypeText(type) {
    const typeTexts = {
        'deposit': 'Depósito',
        'withdraw': 'Retiro',
        'invoice': 'Factura',
        'salary': 'Salario'
    };
    return typeTexts[type] || type;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('es-ES', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
    });
}

function formatTime(dateString) {
    const date = new Date(dateString);
    return date.toLocaleTimeString('es-ES', {
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Comunicación con el juego
function fetch(url, options) {
    return new Promise((resolve, reject) => {
        $.post(url, options?.body ? JSON.parse(options.body) : {}, function(data) {
            resolve({ json: () => Promise.resolve(data) });
        });
    });
}

// Inicializar jQuery para NUI
$(function() {
    window.addEventListener('message', function(event) {
        if (event.data.action === 'openTablet') {
            $('#homeScreen').show();
        }
    });
    
    // Cerrar tablet con Escape
    $(document).keyup(function(e) {
        if (e.keyCode === 27) { // Escape
            closeTablet();
        }
    });
});