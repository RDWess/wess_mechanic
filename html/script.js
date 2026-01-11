let currentScreen = 'screen-lock';

// 1. ACTUALIZACIÓN DE RELOJ Y FECHA (Presente en tus capas)
function updateDateTime() {
    const now = new Date();
    const timeString = now.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' });
    const dateString = now.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long' });

    ['lock-time', 'home-time'].forEach(id => {
        if(document.getElementById(id)) document.getElementById(id).innerText = timeString;
    });
    ['lock-date', 'home-date'].forEach(id => {
        if(document.getElementById(id)) document.getElementById(id).innerText = dateString;
    });
}
setInterval(updateDateTime, 1000);

// 2. RECEPCIÓN DE MENSAJES DESDE LUA (Cuando abres la tablet)
window.addEventListener('message', function(event) {
    let item = event.data;
    if (item.type === "openTablet") {
        document.getElementById('tablet-wrapper').style.display = 'flex';
        // Si el servidor dice que ya tiene cuenta, vamos directo al home
        if (item.hasAccount) {
            showScreen('screen-home');
        } else {
            showScreen('screen-lock');
        }
    }
    if (item.type === "closeTablet") {
        document.getElementById('tablet-wrapper').style.display = 'none';
    }
});

// 3. LÓGICA DE CAPAS (FIGMA)
function attemptUnlock() {
    // Consultamos al servidor si existe cuenta de tablet
    fetch(`https://${GetParentResourceName()}/checkAccount`, { method: 'POST' })
    .then(resp => resp.json())
    .then(data => {
        if (data.exists) {
            showScreen('screen-home');
        } else {
            showScreen('screen-login');
        }
    });
}

// Procesar el Login/Registro de tu diseño
function processAuth() {
    const user = document.getElementById('input-user').value;
    const pass = document.getElementById('input-pass').value;

    if (user.length > 2 && pass.length > 3) {
        fetch(`https://${GetParentResourceName()}/registerTabletAccount`, {
            method: 'POST',
            body: JSON.stringify({ usuario: user, clave: pass })
        }).then(() => showScreen('screen-home'));
    } else {
        // Podrías añadir una notificación de ox_lib aquí
        console.log("Datos insuficientes");
    }
}

// 4. FUNCIONES DE LAS APPS (Vínculo con tus 19 capas)

// App Reparar (Botón Reparar de tu Figma)
function triggerRepair() {
    fetch(`https://${GetParentResourceName()}/actionRepair`, { 
        method: 'POST',
        body: JSON.stringify({ cost: 500 }) // Ejemplo de costo de materiales
    });
}

// App Facturas (Enviar los marcos de texto a la DB)
function sendInvoiceFromTablet() {
    const client = document.getElementById('invoice-client-name').value;
    const amount = document.getElementById('invoice-amount').value;
    const vehicle = document.getElementById('invoice-vehicle').value;

    fetch(`https://${GetParentResourceName()}/createInvoice`, {
        method: 'POST',
        body: JSON.stringify({
            clientName: client,
            amount: amount,
            vehicle: vehicle
        })
    });
    // Volver al home después de enviar
    showScreen('screen-home');
}

// Navegación entre pantallas
function showScreen(screenId) {
    const frame = document.getElementById('tablet-frame');
    document.querySelectorAll('.screen').forEach(s => s.style.display = 'none');
    
    let target = document.getElementById(screenId);
    if(target) target.style.display = 'flex';

    currentScreen = screenId;

    // Cambio de fondo dinámico como pediste
    if (screenId === 'screen-lock') {
        frame.className = 'bg-lock';
    } else {
        frame.className = 'bg-home';
    }
}

// 5. CIERRE Y NAVEGACIÓN FÍSICA
function goHome() { showScreen('screen-home'); }

document.onkeyup = function (data) {
    if (data.which == 27) { // ESC
        fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
        document.getElementById('tablet-wrapper').style.display = 'none';
    }
};