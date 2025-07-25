# Установка

TODO: 
  - nextcloud поднимается на sqlite, приходится выполнять руками миграцию в pg через ./occ внутри контейера
  - vuetorrent коректно поднимается пока только за счет ранее созданного и корректно наполненого pv , надо бы создать configmap
  - то же касается jackett , чтобы получить токен надо поковырять исходники в pv 
  - watchtower совсем никак не настроен, просто молча работает
  - пока не проверен guamamone на rdp , vpn и ssh точно работают
  - для forgejo хотелось бы в будущем добавить и forgejo-runner
  - мои nfs-csi прописаны в самых неожиданых местах ))
  - посмотреть вариант окрывать порты tcp ingress-nginx лишь на нужных нодах, а не на всех где поднят ingress 



Следуйте этим шагам, чтобы установить ArgoCD и запустить инфраструктуру:

```
helm upgrade --install argocd argo/argo-cd -n argocd -f ./applications-helm/argocd/argocd/values.yaml --create-namespace
kubectl apply -f main-application.yaml -n argocd
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
kubectl port-forward svc/argocd-server -n argocd 8443:80 
```
затем откройте http://127.0.0.1:8443 в браузере и войдите в интерфейс. Игнорируйте предупреждение о сертификате (в Chrome можно использовать трюк: на странице ошибки введите `thisisunsafe`) , В UI ArgoCD откройте Settings → Repositories и подключите свой git-репозиторий вручную (обычно достаточно указать "Repository URL" и "SSH private key data")

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

### это форк от https://github.com/alexclear/not-so-awesome-gitops-infra
