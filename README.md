# terraform-gcp-iam

## Descripción del proyecto

Este proyecto de Terraform gestiona **Service Accounts de GCP** y sus permisos IAM de forma declarativa, segura y reutilizable. Utiliza un módulo central (`modules/iam`) que acepta un mapa de cuentas de servicio, de modo que agregar nuevas cuentas no requiere modificar el módulo.

---

## Prerequisitos

| Herramienta | Versión mínima |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | 1.14.8 |
| [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install) | Cualquier versión reciente |

---

## Pasos para conectar GCP con Terraform

### 1. Instalar Google Cloud SDK

Descarga e instala el SDK desde la documentación oficial:
https://cloud.google.com/sdk/docs/install

Verifica la instalación:
```bash
gcloud --version
```

### 2. Autenticarse con Application Default Credentials (ADC)

```bash
gcloud auth application-default login
```

Esto abrirá el navegador para completar el flujo OAuth. Las credenciales se guardan localmente y Terraform las usa automáticamente.

### 3. Establecer el proyecto activo

```bash
gcloud config set project PROJECT_ID
```

Reemplaza `PROJECT_ID` con el ID de tu proyecto GCP.

### 4. Habilitar las APIs requeridas

```bash
gcloud services enable iam.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

### 5. Crear una Service Account de Terraform con privilegios mínimos

```bash
# Crear la service account
gcloud iam service-accounts create terraform-sa \
  --display-name="Terraform Service Account"

# Asignar roles de privilegio mínimo
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:terraform-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountCreator"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:terraform-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"
```

### 6. Exportar credenciales

**Opción A — Application Default Credentials (recomendado para desarrollo local):**  
Ya configurado en el paso 2. No se requiere configuración adicional.

**Opción B — Variable de entorno con archivo de clave:**
```bash
gcloud iam service-accounts keys create key.json \
  --iam-account=terraform-sa@PROJECT_ID.iam.gserviceaccount.com

export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/key.json"
```

> ⚠️ Nunca incluyas archivos `key.json` en el repositorio. Agrega `*.json` a `.gitignore`.

### 7. Ejecutar Terraform

```bash
cd environments/develop

# Copiar el archivo de variables de ejemplo
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con los valores reales

terraform init
terraform plan
terraform apply
```

---

## Cómo clonar y usar el proyecto

```bash
git clone <URL_DEL_REPOSITORIO>
cd terraform-gcp-iam/environments/develop

cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con tu project_id y service accounts

terraform init
terraform plan    # Revisar los cambios antes de aplicar
terraform apply   # Aplicar los cambios
```

---

## Estructura de archivos

```
terraform-gcp-iam/
├── environments/
│   └── develop/
│       ├── main.tf                   # Provider, versión de Terraform y llamada al módulo
│       ├── variables.tf              # Declaración de variables del entorno
│       ├── terraform.tfvars.example  # Ejemplo de valores (copiar a terraform.tfvars)
│       └── backend.tf                # Backend remoto GCS (comentado por defecto)
├── modules/
│   └── iam/
│       ├── main.tf                   # Recursos google_service_account y google_project_iam_member
│       ├── variables.tf              # Variables del módulo
│       └── outputs.tf                # Outputs: emails e IDs de las service accounts
└── README.md
```

---

## Cómo agregar una nueva Service Account sin tocar el módulo

Solo edita `terraform.tfvars` en el entorno correspondiente y agrega una nueva entrada al mapa `service_accounts`:

```hcl
service_accounts = {
  # Cuentas existentes...
  "sa-backend-dev" = {
    display_name = "Backend Service Account - Develop"
    roles        = ["roles/storage.objectViewer", "roles/cloudsql.client"]
  }

  # Nueva cuenta — solo agrega el bloque aquí:
  "sa-pubsub-dev" = {
    display_name = "PubSub Service Account - Develop"
    roles        = ["roles/pubsub.subscriber"]
  }
}
```

Luego ejecuta:
```bash
terraform plan
terraform apply
```

No es necesario modificar ningún archivo `.tf` del módulo.

---

## ⚠️ Advertencia: iam_policy vs iam_member

Este proyecto usa exclusivamente `google_project_iam_member` (**aditivo**).

| Recurso | Comportamiento | Riesgo |
|---|---|---|
| `google_project_iam_policy` | **Reemplaza** toda la política IAM del proyecto | 🔴 Puede eliminar permisos de otros usuarios/sistemas |
| `google_project_iam_binding` | **Reemplaza** todos los miembros de un rol específico | 🟡 Puede quitar acceso a cuentas no gestionadas por Terraform |
| `google_project_iam_member` | **Agrega** un binding sin tocar los existentes | 🟢 Seguro para uso en proyectos compartidos |

**Nunca uses `google_project_iam_policy` en proyectos con recursos ya existentes.** Un `terraform apply` podría eliminar todos los permisos IAM del proyecto de forma irreversible.
