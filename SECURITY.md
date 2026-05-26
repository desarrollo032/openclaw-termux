# 🔒 Política de Seguridad — OpenClaw

## 🎯 Alcance

OpenClaw se compromete a mantener la seguridad de sus usuarios y del ecosistema de código abierto. Esta política describe cómo reportar vulnerabilidades y qué esperar del proceso.

---

## ✅ Versiones Soportadas

Actualmente, solo la **última versión estable** recibe parches de seguridad. Mantén tu instalación actualizada.

| Versión          | Soportada         |
| ---------------- | ----------------- |
| Última estable   | ✅ Sí             |
| Release candidat | ⚠️ Parcial       |
| < v1.8.0         | ❌ No             |

---

## 🐛 Reportar una Vulnerabilidad

Si descubres una vulnerabilidad de seguridad en OpenClaw, **por favor repórtala de forma responsable**.

### 📧 Cómo reportar

1. **No abras un issue público** — las vulnerabilidades de seguridad deben manejarse de forma privada.
2. Envía un correo a: [pendiente — próximamente]
3. Incluye la mayor cantidad de detalles posible:
   - Descripción clara del problema
   - Pasos para reproducir
   - Versión de OpenClaw afectada
   - Dispositivo Android y versión del SO
   - Posible impacto
   - Sugerencia de mitigación (si aplica)

### ⏱️ Respuesta esperada

| Plazo         | Acción                                    |
| ------------- | ----------------------------------------- |
| 48 horas      | Acuse de recibo                           |
| 7 días        | Evaluación inicial y plan de acción       |
| 30 días       | Parche o mitigación (dependiendo del caso) |

### 🔄 Proceso

1. **Reportas** la vulnerabilidad por correo electrónico
2. **Confirmamos** recepción en 48 horas
3. **Evaluamos** el reporte y determinamos la severidad
4. **Desarrollamos** un parche
5. **Publicamos** el parche en una nueva versión
6. **Revelamos** públicamente después de la corrección (con crédito al reportante)

---

## 🛡️ Buenas Prácticas

### Para usuarios

- Mantén OpenClaw actualizado a la última versión
- Usa contraseñas seguras para el acceso SSH
- No expongas el gateway a internet sin autenticación
- Revisa los permisos que otorgas a la app en Android
- Desactiva servicios que no estés usando activamente

### Para desarrolladores

- No incluyas secretos, API keys o tokens en el código
- Usa variables de entorno para configuraciones sensibles
- Valida todos los inputs que llegan desde el canal nativo
- Sigue el principio de mínimo privilegio
- Reporta cualquier fuga de información que descubras

---

## 🚨 Vulnerabilidades Conocidas Anteriores

| ID | Versión | Descripción | Estado |
|----|---------|-------------|--------|
| —  | —       | Sin reportes previos | 🟢 |

---

## 📚 Recursos

- [Código de Conducta](CODE_OF_CONDUCT.md)
- [Guía de Contribución](CONTRIBUTING.md)
- [Reportar un Bug](https://github.com/desarrollo032/openclaw-termux/issues)

---

<div align="center">

*🔐 La seguridad es responsabilidad de todos — gracias por contribuir a mantener OpenClaw seguro*

</div>
