# Установка

Следуйте этим шагам, чтобы установить ArgoCD и запустить инфраструктуру:

1) `kubectl create ns argocd`
2) `helm upgrade --install argocd argo/argo-cd -n argocd --version=7.8.26 -f ./applications-helm/argocd/argocd/values.yaml`
3) `kubectl apply -f main-application.yaml -n argocd`
4) `kubectl get secrets argocd-initial-admin-secret -n argocd -o yaml` — чтобы получить пароль администратора UI ArgoCD в base64-кодировке
5) `kubectl port-forward svc/argocd-server -n argocd 8443:80` — проброс порта ArgoCD, затем откройте http://127.0.0.1:8443 в браузере и войдите в интерфейс. Игнорируйте предупреждение о сертификате (в Chrome можно использовать трюк: на странице ошибки введите `thisisunsafe`)
6) В UI ArgoCD откройте Settings → Repositories и подключите свой git-репозиторий вручную (обычно достаточно указать "Repository URL" и "SSH private key data")
7) Вы не сможете добавить все приложения сразу, потому что CRD для мониторинга устанавливаются отдельно. Отключите мониторинг у ArgoCD, оператора Rook, кластера Rook Ceph и контроллера Nginx ingress, пока не развернёте стек Prometheus и его CRD в namespace `monitoring`

# Структура репозитория инфраструктуры

Этот репозиторий содержит конфигурации инфраструктуры Kubernetes, управляемые через ArgoCD. Структура построена по принципам GitOps — изменения в репозитории автоматически синхронизируются с целевым кластером.

## Основные компоненты

### Главное приложение
- Описано в [`applicationsets/main-application.yaml`](applicationsets/main-application.yaml)
- Оркестрация всех остальных приложений через ApplicationSet

### ApplicationSet'ы
1. **Приложения на базе Helm**
   - Генерируются из [`applicationsets/helm-applicationset.yaml`](applicationsets/helm-applicationset.yaml)
   - Обрабатывают приложения в директории `applications-helm/`
   - Каждое приложение развёртывается через Helmfile

2. **Приложения на основе raw-манифестов**
   - Генерируются из [`applicationsets/non-helm-applicationset.yaml`](applicationsets/non-helm-applicationset.yaml)
   - Обрабатывают приложения в директории `applications-raw/`
   - Содержат обычные Kubernetes-манифесты

## Структура директорий

### applications-helm/
- Каждая директория верхнего уровня соответствует Kubernetes namespace
  - Пример: `applications-helm/argocd/`
- Каждая папка namespace содержит подпапки, соответствующие приложениям ArgoCD
  - Пример: `applications-helm/argocd/argocd/` содержит:
    - `helmfile.yaml` — конфигурация Helmfile
    - `values.yaml` — значения для Helm

### applications-raw/
- Каждая директория верхнего уровня соответствует Kubernetes namespace
  - Пример: `applications-raw/argocd/`
- Каждая папка namespace содержит подпапки, соответствующие приложениям ArgoCD
  - Пример: `applications-raw/argocd/argocd-secrets/` содержит YAML-файлы с raw-манифестами Kubernetes

### Важное замечание
- **Уникальность имён приложений**: Имя каждого ArgoCD-приложения (2-й уровень вложенности в `applications-helm` и `applications-raw`) должно быть уникальным во всём кластере. Дублирующиеся имена вызовут конфликты в ArgoCD и нарушат синхронизацию.

  **Практический пример**:
  - ❌ Недопустимая структура (повторяющиеся имена приложений):
    ```
    applications-raw/
    ├── application/
    │   └── network-policies/  # Имя приложения: network-policies
    │       └── policy1.yaml
    └── pg-application/
        └── network-policies/  # Имя приложения: network-policies (ДУБЛИКАТ!)
            └── policy2.yaml
    ```
  - ✅ Допустимая структура (уникальные имена приложений):
    ```
    applications-raw/
    ├── application/
    │   └── network-policies-application/  # Имя приложения: network-policies-application
    │       └── policy1.yaml
    └── pg-application/
        └── network-policies-pg-application/  # Имя приложения: network-policies-pg-application
            └── policy2.yaml
    ```

## Рабочий процесс
1. ArgoCD отслеживает этот репозиторий
2. `main-application.yaml` запускает два ApplicationSet'а
3. ApplicationSet'ы сканируют свои директории:
   - `applications-helm/` → приложения на Helmfile
   - `applications-raw/` → raw-манифесты
4. Приложения разворачиваются в соответствующие namespace'ы целевого кластера
это форк от https://github.com/alexclear/not-so-awesome-gitops-infra
