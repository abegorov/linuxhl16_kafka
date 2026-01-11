# Очередь логов: Kafka между Logstash и Elasticsearch

## Цель

Настроить сбор логов, использовать **Kafka** как промежуточную очередь между **Logstash** и **Kibana**.

## Задание

1. Развернуть **Kafka** в кластерном режиме.
2. Создать несколько топиков с несколькими партициями и репликами.
3. Установить на каждом узле агент для сбора логов.
4. Настроить отправку логов в соответствующие топики **Kafka**.
5. Развернуть кластер **ELK** (**Elasticsearch**, **Logstash**, **Kibana**).
6. Настроить **Logstash** для чтения данных из топиков **Kafka** и записи их в отдельные индексы **Elasticsearch**.
7. Создать **Data View** в **Kibana** и убедиться, что логи коректно отображаются.

## Реализация

Проект базируется на предудущем проекте [linuxhl14_elasticsearch](https://github.com/abegorov/linuxhl14_elasticsearch) (но с добавлением **Kafka**).

Задание сделано так, чтобы его можно было запустить как в **Vagrant**, так и в **Yandex Cloud**. После запуска происходит развёртывание следующих виртуальных машин:

- **kfk-backend-01** - **NetBox**, **patroni**, **redis**, **angie**;
- **kfk-backend-02** - **NetBox**, **patroni**, **redis**, **angie**;
- **kfk-backend-03** - **NetBox**, **patroni**, **redis**, **angie**;
- **kfk-es-01** - **Elasticsearch**, **kafka**;
- **kfk-es-02** - **Elasticsearch**, **kafka**;
- **kfk-es-03** - **Elasticsearch**, **kafka**.

В независимости от того, как созданы виртуальные машины, для их настройки запускается **Ansible Playbook** [provision.yml](provision.yml) который запускает следующие роли:

- **angie** - устанавливает и настраивает **angie**;
- **apt_sources** - настраивает репозитории для пакетного менеджера **apt** (используется [mirror.yandex.ru](https://mirror.yandex.ru)).
- **bach_completion** - устанавливает пакет **bash-completion**.
- **chrony** - устанавливает **chrony** для синхронизации времени между узлами.
- **elastic_repo** - настраивает репозиторий для **elasticsearch**, **kibana** и **logstash** (используется [mirror.yandex.ru/mirrors/elastic/8](https://mirror.yandex.ru/mirrors/elastic/8))/
- **elasticsearch** - устанавливает и настраивает **elasticsearch**.
- **etcd** - устанавливает и настраивает кластер **etcd** для его дальнейшего использования **patroni**.
- **filebeat** - устанавливает и настраивает **filebeat**.
- **haproxy** - устанавливает и настраивает **haproxy** для проксирования запросов к **redis** и **postgresql**.
- **hosts** - прописывает адреса всех узлов в `/etc/hosts`.
- **kafka** - устанавливает и настраивает кластер **kafka**.
- **keepalived** - устанавливает и настраивает **keepalived** при разворачивании в **vagrant**.
- **kibana** - устанавливает и настраивает **kibana**.
- **kibana_dataview** - добавляет указанные **Data views** в индексы **kibana** в **elasticsearch**.
- **locale_gen** - генерит локаль **ru_RU.UTF-8** для последующего использования в **postgresql**.
- **logstash** - устанавливает и настраивает **logstash**.
- **netbox** - устанавливает и настраивает **netbox**.
- **patroni** - устанавливает и настраивает кластер **patroni**.
- **patroni_db** - создаёт базу данных в кластере **patroni** (определяет лидера и создаёт её на лидере).
- **patroni_facts** - собирает информацию о членах кластера **patroni** (определяет лидера).
- **patroni_privs** - настраивает права доступа к базам данных в кластере **patroni**.
- **patroni_user** - создаёт пользователей в кластере **patroni**.
- **pgbouncer** - устанавливает и настраивает **pgbouncer**.
- **pgdg_repo** - устанавливает репозиторий **pgdb** для **patroni** и **postgresql**.
- **redis** - устанавливает и настраивает **redis** (с репликацией на другие узлы).
- **redis_repo** - устанавливает и настраивает репозиторий для **redis**.
- **redis_sentinel** - устанавливает и настраивает **redis sentinel** для автоматического переключения мастера в кластере **redis**.
- **system_groups** - создаёт группы пользователей **Linux**.
- **system_users** - создаёт группы пользователей **Linux**.
- **tls_ca** - создаёт сертификаты для корневых центров сертификации.
- **tls_certs** - создаёт сертификаты для узлов.
- **tls_copy** - копирует серитификаты на узел.
- **wait_connection** - ожидает доступность виртуальных машин.

Данные роли настраиваются с помощью переменных, определённых в следующих файлах:

- [group_vars/all/angie.yml](group_vars/all/angie.yml) - общие настройки **angie**;
- [group_vars/all/ansible.yml](group_vars/all/ansible.yml) - общие переменные **ansible** для всех узлов;
- [group_vars/all/certs.yml](group_vars/all/certs.yml) - настройки генерации сертификатов для СУБД и **angie**;
- [group_vars/all/hosts.yml](group_vars/all/hosts.yml) - настройки для роли **hosts** (список узлов, которые нужно добавить в `/etc/hosts`);
- [group_vars/backend/angie.yml](group_vars/backend/angie.yml) - настройки **angie** для узлов **backend**;
- [group_vars/backend/certs.yml](group_vars/backend/certs.yml) - настройки генерации сертификатов для **backend**;
- [group_vars/backend/filebeat.yml](group_vars/backend/filebeat.yml) - настройки для **filebeat** для **backend**;
- [group_vars/backend/haproxy.yml](group_vars/backend/haproxy.yml) - настройки **haproxy**  для узлов **backend** (проксирования не лидера **patroni** и **redis**);
- [group_vars/backend/keepalived.yml](group_vars/backend/keepalived.yml) - настройки **keepalived** для узлов **backend**;
- [group_vars/backend/netbox.yml](group_vars/backend/netbox.yml) - настройки **netbox** для узлов **backend**;
- [group_vars/backend/patroni.yml](group_vars/backend/patroni.yml) - настройки **patroni** для узлов **backend**;
- [group_vars/backend/pgbouncer.yml](group_vars/backend/pgbouncer.yml) - настройки **pgbouncer** для узлов **backend**;
- [group_vars/backend/redis.yml](group_vars/backend/redis.yml) - настройки **redis** для узлов **backend**;
- [group_vars/backend/users.yml](group_vars/backend/users.yml) - настройки создания пользователей и групп на узлах **backend**;
- [group_vars/elasticsearch/certs.yml](group_vars/elasticsearch/certs.yml) - настройки генерации сертификатов для **elasticsearch**;
- [group_vars/elasticsearch/elasticsearch.yml](group_vars/elasticsearch/elasticsearch.yml) - настройки для **elasticsearch**;
- [group_vars/elasticsearch/filebeat.yml](group_vars/elasticsearch/filebeat.yml) - настройки для **filebeat** для **elasticsearch**;
- [group_vars/elasticsearch/kafka.yml](group_vars/elasticsearch/kafka.yml) - настройки для **kafka** для **elasticsearch**;
- [group_vars/elasticsearch/kibana.yml](group_vars/elasticsearch/kibana.yml) - настройки для **kibana** для **elasticsearch**;
- [group_vars/elasticsearch/logstash.yml](group_vars/elasticsearch/logstash.yml) - настройки для **logstash** для **elasticsearch**;
- [host_vars/kfk-backend-01/redis.yml](host_vars/kfk-backend-01/redis.yml) - настройки **redis** для **kfk-backend-01**;
- [host_vars/kfk-backend-01/keepalived.yml](host_vars/kfk-backend-01/keepalived.yml) - настройки **keepalived** для **kfk-backend-01**;
- [host_vars/kfk-backend-02/keepalived.yml](host_vars/kfk-backend-02/keepalived.yml) - настройки **keepalived** для **kfk-backend-02**;
- [host_vars/kfk-backend-03/keepalived.yml](host_vars/kfk-backend-03/keepalived.yml) - настройки **keepalived** для **kfk-backend-03**;
- [host_vars/kfk-es-01/elasticsearch.yml](host_vars/kfk-es-01/elasticsearch.yml) - настройки **elasticsearch** для **kfk-es-01** (позволяет установить пароль кластера только на этом узле).
- [host_vars/kfk-es-01/kafka.yml](host_vars/kfk-es-01/kafka.yml) - настройки **kafka** для **kfk-es-01** (node_id).
- [host_vars/kfk-es-02/kafka.yml](host_vars/kfk-es-02/kafka.yml) - настройки **kafka** для **kfk-es-02** (node_id).
- [host_vars/kfk-es-03/kafka.yml](host_vars/kfk-es-03/kafka.yml) - настройки **kafka** для **kfk-es-03** (node_id).

## Запуск

### Запуск в Yandex Cloud

1. Необходимо установить и настроить утилиту **yc** по инструкции [Начало работы с интерфейсом командной строки](https://yandex.cloud/ru/docs/cli/quickstart).
2. Необходимо установить **Terraform** по инструкции [Начало работы с Terraform](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-quickstart).
3. Необходимо установить **Ansible**.
4. Необходимо перейти в папку проекта и запустить скрипт [up.sh](up.sh).

### Запуск в Vagrant (VirtualBox)

Необходимо скачать **VagrantBox** для **bento/ubuntu-24.04** версии **202510.26.0** и добавить его в **Vagrant** под именем **bento/ubuntu-24.04/202510.26.0**. Сделать это можно командами:

```shell
curl -OL https://app.vagrantup.com/bento/boxes/ubuntu-24.04/versions/202510.26.0/providers/virtualbox/amd64/vagrant.box
vagrant box add vagrant.box --name "bento/ubuntu-24.04/202510.26.0"
rm vagrant.box
```

После этого нужно сделать **vagrant up** в папке проекта.

## Проверка

Протестировано в **OpenSUSE Tumbleweed**:

- **Vagrant 2.4.9**
- **VirtualBox 7.2.4_SUSE r170995**
- **Ansible 2.20.1**
- **Python 3.13.9**
- **Jinja2 3.1.6**
- **Terraform 1.14.3**

После запуска **NetBox** должен открываться по **IP** балансировщика. Для **Yandex Cloud** адрес можно узнать в выводе **terraform output** в поле **load_balancer** (смотри [outputs.tf](outputs.tf)). Для **vagrant** это (можно использовать любой адрес):

- [https://192.168.56.51](https://192.168.56.51) - узел **kfk-backend-01**.
- [https://192.168.56.52](https://192.168.56.52) - узел **kfk-backend-02**.
- [https://192.168.56.53](https://192.168.56.53) - узел **kfk-backend-03**.

Однако **keepalived** настроен таким образом, что при недоступности одного из узлов, его адрес переезжает на один из доступных.

Для начала проверим состояние кластера **kafka**:

```text
root@kfk-es-01:/opt/kafka/4.1.1/bin# ./kafka-metadata-quorum.sh --bootstrap-server 192.168.56.31:9092 --command-config /etc/kafka/server.properties describe --status
ClusterId:              d3hmci7YQre-MuRF8qOF8w
LeaderId:               1
LeaderEpoch:            4
HighWatermark:          10528
MaxFollowerLag:         0
MaxFollowerLagTimeMs:   0
CurrentVoters:          [{"id": 1, "endpoints": ["CONTROLLER://192.168.56.31:9093"]}, {"id": 2, "endpoints": ["CONTROLLER://192.168.56.32:9093"]}, {"id": 3, "endpoints": ["CONTROLLER://192.168.56.33:9093"]}]
CurrentObservers:       []
root@kfk-es-01:/opt/kafka/4.1.1/bin# ./kafka-metadata-quorum.sh --bootstrap-server 192.168.56.31:9092 --command-config /etc/kafka/server.properties describe --replication --human-readable
NodeId  DirectoryId             LogEndOffset    Lag     LastFetchTimestamp      LastCaughtUpTimestamp   Status
1       AAAAAAAAAAAAAAAAAAAAAA  10721           0       10 ms ago               18 ms ago               Leader
2       AAAAAAAAAAAAAAAAAAAAAA  10721           0       427 ms ago              427 ms ago              Follower
3       AAAAAAAAAAAAAAAAAAAAAA  10721           0       430 ms ago              430 ms ago              Follower
```

Проверим создались ли топики:

```text
root@kfk-es-01:/opt/kafka/4.1.1/bin# ./kafka-topics.sh --bootstrap-server 192.168.56.31:9092 --command-config /etc/kafka/server.properties --describe
Topic: logstash TopicId: 1LzxbCPgQrmtTbgLJ5HnbA PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1,segment.bytes=1073741824
        Topic: logstash Partition: 0    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: logstash Partition: 1    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: logstash Partition: 2    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
Topic: system   TopicId: dKYeXK1UQ2u5yMuPOZwu1w PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1,segment.bytes=1073741824
        Topic: system   Partition: 0    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: system   Partition: 1    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: system   Partition: 2    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
Topic: elasticsearch    TopicId: vWAWHz4pSMasV5vHO8BgWg PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1,segment.bytes=1073741824
        Topic: elasticsearch    Partition: 0    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: elasticsearch    Partition: 1    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: elasticsearch    Partition: 2    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
Topic: nginx    TopicId: 7gGHZSKoTXCJC7C_BYVI_Q PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1,segment.bytes=1073741824
        Topic: nginx    Partition: 0    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: nginx    Partition: 1    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: nginx    Partition: 2    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
Topic: postgresql       TopicId: tqCNQrEtReGKs1Oi3e9UuA PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1,segment.bytes=1073741824
        Topic: postgresql       Partition: 0    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: postgresql       Partition: 1    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: postgresql       Partition: 2    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
Topic: kafka    TopicId: jiW_W-Y9Qmurup2mWjkwdg PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1,segment.bytes=1073741824
        Topic: kafka    Partition: 0    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: kafka    Partition: 1    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: kafka    Partition: 2    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
Topic: haproxy  TopicId: 6LBr4f2gQz-bRFrH-hArAA PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1,segment.bytes=1073741824
        Topic: haproxy  Partition: 0    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: haproxy  Partition: 1    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: haproxy  Partition: 2    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
Topic: kibana   TopicId: fp6FQw82SWezWQJ5C8TKJQ PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1,segment.bytes=1073741824
        Topic: kibana   Partition: 0    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: kibana   Partition: 1    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: kibana   Partition: 2    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
Topic: __consumer_offsets       TopicId: tYX8PH3yTZWS5wqajpCZFQ PartitionCount: 50      ReplicationFactor: 3    Configs: compression.type=producer,min.insync.replicas=1,cleanup.policy=compact,segment.bytes=104857600
        Topic: __consumer_offsets       Partition: 0    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 1    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 2    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 3    Leader: 2       Replicas: 2,1,3 Isr: 2,1,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 4    Leader: 1       Replicas: 1,3,2 Isr: 1,3,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 5    Leader: 3       Replicas: 3,2,1 Isr: 3,2,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 6    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 7    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 8    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 9    Leader: 1       Replicas: 1,3,2 Isr: 1,3,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 10   Leader: 3       Replicas: 3,2,1 Isr: 3,2,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 11   Leader: 2       Replicas: 2,1,3 Isr: 2,1,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 12   Leader: 3       Replicas: 3,2,1 Isr: 3,2,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 13   Leader: 2       Replicas: 2,1,3 Isr: 2,1,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 14   Leader: 1       Replicas: 1,3,2 Isr: 1,3,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 15   Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 16   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 17   Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 18   Leader: 3       Replicas: 3,2,1 Isr: 3,2,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 19   Leader: 2       Replicas: 2,1,3 Isr: 2,1,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 20   Leader: 1       Replicas: 1,3,2 Isr: 1,3,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 21   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 22   Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 23   Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 24   Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 25   Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 26   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 27   Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 28   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 29   Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 30   Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 31   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 32   Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 33   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 34   Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 35   Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 36   Leader: 1       Replicas: 1,3,2 Isr: 1,3,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 37   Leader: 3       Replicas: 3,2,1 Isr: 3,2,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 38   Leader: 2       Replicas: 2,1,3 Isr: 2,1,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 39   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 40   Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 41   Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 42   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 43   Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 44   Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 45   Leader: 2       Replicas: 2,1,3 Isr: 2,1,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 46   Leader: 1       Replicas: 1,3,2 Isr: 1,3,2      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 47   Leader: 3       Replicas: 3,2,1 Isr: 3,2,1      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 48   Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: __consumer_offsets       Partition: 49   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
Topic: redis    TopicId: 9CZ3t0hiQqGSfJRjy_ki6w PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1,segment.bytes=1073741824
        Topic: redis    Partition: 0    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr:
        Topic: redis    Partition: 1    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr:
        Topic: redis    Partition: 2    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr:
```

Проверим состояние групп:

```text
root@kfk-es-01:/opt/kafka/4.1.1/bin# ./kafka-consumer-groups.sh --bootstrap-server 192.168.56.31:9092 --command-config /etc/kafka/server.properties --describe --all-groups

GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID                                      HOST            CLIENT-ID
logstash        logstash        1          554             554             0               kfk-es-02-0-825704f1-ae42-49a9-946e-5337d52b90a5 /192.168.56.32  kfk-es-02-0
logstash        system          1          14590           14590           0               kfk-es-02-0-825704f1-ae42-49a9-946e-5337d52b90a5 /192.168.56.32  kfk-es-02-0
logstash        postgresql      1          1184            1184            0               kfk-es-02-0-825704f1-ae42-49a9-946e-5337d52b90a5 /192.168.56.32  kfk-es-02-0
logstash        nginx           1          21              21              0               kfk-es-02-0-825704f1-ae42-49a9-946e-5337d52b90a5 /192.168.56.32  kfk-es-02-0
logstash        elasticsearch   1          2391            2391            0               kfk-es-02-0-825704f1-ae42-49a9-946e-5337d52b90a5 /192.168.56.32  kfk-es-02-0
logstash        kafka           1          1260            1260            0               kfk-es-02-0-825704f1-ae42-49a9-946e-5337d52b90a5 /192.168.56.32  kfk-es-02-0
logstash        haproxy         1          101             101             0               kfk-es-02-0-825704f1-ae42-49a9-946e-5337d52b90a5 /192.168.56.32  kfk-es-02-0
logstash        kibana          1          239             239             0               kfk-es-02-0-825704f1-ae42-49a9-946e-5337d52b90a5 /192.168.56.32  kfk-es-02-0
logstash        redis           1          230             230             0               kfk-es-02-0-825704f1-ae42-49a9-946e-5337d52b90a5 /192.168.56.32  kfk-es-02-0
logstash        logstash        2          543             543             0               kfk-es-03-0-04014fb1-1641-4424-9fb4-fe0c56429b95 /192.168.56.33  kfk-es-03-0
logstash        system          2          14755           14755           0               kfk-es-03-0-04014fb1-1641-4424-9fb4-fe0c56429b95 /192.168.56.33  kfk-es-03-0
logstash        kibana          2          239             239             0               kfk-es-03-0-04014fb1-1641-4424-9fb4-fe0c56429b95 /192.168.56.33  kfk-es-03-0
logstash        postgresql      2          1184            1184            0               kfk-es-03-0-04014fb1-1641-4424-9fb4-fe0c56429b95 /192.168.56.33  kfk-es-03-0
logstash        kafka           2          1239            1239            0               kfk-es-03-0-04014fb1-1641-4424-9fb4-fe0c56429b95 /192.168.56.33  kfk-es-03-0
logstash        elasticsearch   2          2368            2368            0               kfk-es-03-0-04014fb1-1641-4424-9fb4-fe0c56429b95 /192.168.56.33  kfk-es-03-0
logstash        nginx           2          18              18              0               kfk-es-03-0-04014fb1-1641-4424-9fb4-fe0c56429b95 /192.168.56.33  kfk-es-03-0
logstash        haproxy         2          100             100             0               kfk-es-03-0-04014fb1-1641-4424-9fb4-fe0c56429b95 /192.168.56.33  kfk-es-03-0
logstash        redis           2          230             230             0               kfk-es-03-0-04014fb1-1641-4424-9fb4-fe0c56429b95 /192.168.56.33  kfk-es-03-0
logstash        logstash        0          543             543             0               kfk-es-01-0-af7c5e94-ae6e-4c9c-a3d7-927b3c54575a /192.168.56.31  kfk-es-01-0
logstash        postgresql      0          1185            1185            0               kfk-es-01-0-af7c5e94-ae6e-4c9c-a3d7-927b3c54575a /192.168.56.31  kfk-es-01-0
logstash        nginx           0          21              21              0               kfk-es-01-0-af7c5e94-ae6e-4c9c-a3d7-927b3c54575a /192.168.56.31  kfk-es-01-0
logstash        kafka           0          1215            1215            0               kfk-es-01-0-af7c5e94-ae6e-4c9c-a3d7-927b3c54575a /192.168.56.31  kfk-es-01-0
logstash        elasticsearch   0          2373            2373            0               kfk-es-01-0-af7c5e94-ae6e-4c9c-a3d7-927b3c54575a /192.168.56.31  kfk-es-01-0
logstash        redis           0          231             231             0               kfk-es-01-0-af7c5e94-ae6e-4c9c-a3d7-927b3c54575a /192.168.56.31  kfk-es-01-0
logstash        haproxy         0          103             103             0               kfk-es-01-0-af7c5e94-ae6e-4c9c-a3d7-927b3c54575a /192.168.56.31  kfk-es-01-0
logstash        system          0          14582           14582           0               kfk-es-01-0-af7c5e94-ae6e-4c9c-a3d7-927b3c54575a /192.168.56.31  kfk-es-01-0
logstash        kibana          0          279             279             0               kfk-es-01-0-af7c5e94-ae6e-4c9c-a3d7-927b3c54575a /192.168.56.31  kfk-es-01-0
```

Также удобно смотреть всё это с помощью **GUI**, для этого был написан скрипт [kafka-ui.sh](kafka-ui.sh), который при разворачивании в **vagrant** позволяет поднять и настроить **kafbat UI** (графический интерфейс для **kafka**) в **docker** по адресу [localhost:8080](http://localhost:8080):

![Dashboard](images/dashboard.png)
![Brokers](images/brokers.png)
![Topics](images/topics.png)
![Topics/system](images/topics_system.png)
![Consumers](images/consumers.png)
![Consumers/logstash](images/consumers_logstash.png)

Конвейер сбора логов представляет из себя **Filebeat** -> **Kafka** -> **Logstash** -> **ElasticSearch**. Каждое приложение пришет в свой индекс, поэтому если индексы были созданы, то настройка прошла успешно. Зайдём в **Kibana** -> **Stack Management** -> **Data** -> **index Management** (пароль пользователя **elastic** генерится автоматически и доступен в файл [secrets/elasticsearch_elastic_password.txt](secrets/elasticsearch_elastic_password.txt)) и проверим, что все индексы были созданы. Видно, что создалось 8 индексов, все в статусе **green** и у каждого есть одна реплика:

![indexes](images/indexes.png)

Посмотрим содержимое этих индексов через **Kibana** -> **Analytics** -> **Discover**:

![system](images/system.png)
