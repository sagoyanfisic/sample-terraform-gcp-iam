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
# 1. Clonar el repositorio e ingresar al entorno
git clone <URL_DEL_REPOSITORIO>
cd terraform-gcp-iam/environments/develop

# 2. Copiar el archivo de variables de ejemplo
cp terraform.tfvars.example terraform.tfvars

# 3. Editar terraform.tfvars y reemplazar "my-gcp-project-id" con tu project ID real
#    Ejemplo:
#      project_id = "bwai-pucp-01"
nano terraform.tfvars   # o usa el editor de tu preferencia

# 4. Inicializar, planear y aplicar
terraform init
terraform plan
terraform apply
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

El archivo `terraform.tfvars.example` incluye un bloque comentado listo para copiar. El flujo completo es:

**1. Si aún no tienes el archivo de variables, créalo a partir del ejemplo y ajusta el `project_id`:**

```bash
cp terraform.tfvars.example terraform.tfvars
```

Abre `terraform.tfvars` y reemplaza `my-gcp-project-id` con el ID real de tu proyecto GCP:

```hcl
project_id = "bwai-pucp-01"  # <-- cambia esto
```

**2. Agrega la nueva cuenta** descomentando (o agregando) su bloque en `terraform.tfvars`:

```hcl
service_accounts = {
  # Cuentas existentes — no las toques
  "sa-backend-dev" = {
    display_name = "Backend Service Account - Develop"
    roles        = ["roles/storage.objectViewer", "roles/cloudsql.client"]
  }
  "sa-deploy-dev" = {
    display_name = "Deploy Service Account - Develop"
    roles        = ["roles/run.developer"]
  }

  # Nueva cuenta
  "sa-pubsub-dev" = {
    display_name = "PubSub Service Account - Develop"
    roles        = ["roles/pubsub.subscriber", "roles/pubsub.viewer"]
  }
}
```

**3. Revisa qué va a crear Terraform antes de aplicar:**

```bash
terraform plan
```

Deberías ver exactamente 3 recursos nuevos:
- `google_service_account.this["sa-pubsub-dev"]`
- `google_project_iam_member.this["sa-pubsub-dev__roles/pubsub.subscriber"]`
- `google_project_iam_member.this["sa-pubsub-dev__roles/pubsub.viewer"]`

Las cuentas existentes aparecerán como `no changes` — Terraform no las toca.

**4. Aplica los cambios:**

```bash
terraform apply
```

No es necesario modificar ningún archivo `.tf` del módulo.

---

## Cómo modificar una Service Account existente (update)

Supón que `sa-backend-dev` necesita un rol adicional. Solo edita su lista `roles` en `terraform.tfvars`:

```hcl
"sa-backend-dev" = {
  display_name = "Backend Service Account - Develop"
  roles        = ["roles/storage.objectViewer", "roles/cloudsql.client", "roles/bigquery.dataViewer"]  # <-- rol agregado
}
```

Ejecuta el plan para ver exactamente qué cambia:

```bash
terraform plan
```

Terraform mostrará solo el nuevo binding como `+ create` — los roles existentes no se tocan:

```
# module.iam.google_project_iam_member.this["sa-backend-dev__roles/bigquery.dataViewer"] will be created
  + resource "google_project_iam_member" "this" { ... }

Plan: 1 to add, 0 to change, 0 to destroy.
```

```bash
terraform apply
```

---

## Cómo eliminar una Service Account (destroy)

Para eliminar `sa-deploy-dev`, simplemente borra su bloque de `terraform.tfvars`:

```hcl
service_accounts = {
  "sa-backend-dev" = {
    display_name = "Backend Service Account - Develop"
    roles        = ["roles/storage.objectViewer", "roles/cloudsql.client"]
  }
  # sa-deploy-dev eliminado
}
```

El plan mostrará los recursos a destruir:

```bash
terraform plan
```

```
# module.iam.google_project_iam_member.this["sa-deploy-dev__roles/run.developer"] will be destroyed
# module.iam.google_service_account.this["sa-deploy-dev"] will be destroyed

Plan: 0 to add, 0 to change, 2 to destroy.
```

```bash
terraform apply
```

> ⚠️ Eliminar una service account es irreversible en GCP. Si otra aplicación la usa, dejará de funcionar inmediatamente.

---

## ⚠️ Advertencia: iam_policy vs iam_member

Este proyecto usa exclusivamente `google_project_iam_member` (**aditivo**).

| Recurso | Comportamiento | Riesgo |
|---|---|---|
| `google_project_iam_policy` | **Reemplaza** toda la política IAM del proyecto | 🔴 Puede eliminar permisos de otros usuarios/sistemas |
| `google_project_iam_binding` | **Reemplaza** todos los miembros de un rol específico | 🟡 Puede quitar acceso a cuentas no gestionadas por Terraform |
| `google_project_iam_member` | **Agrega** un binding sin tocar los existentes | 🟢 Seguro para uso en proyectos compartidos |

**Nunca uses `google_project_iam_policy` en proyectos con recursos ya existentes.** Un `terraform apply` podría eliminar todos los permisos IAM del proyecto de forma irreversible.
