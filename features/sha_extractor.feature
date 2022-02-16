Feature: SHA Extractor


  Scenario: Check that SHA exctractor service has all the information and interfaces it needs to work properly
    Given SHA extractor service is not started
      And Kafka broker is started on host and port specified in configuration
      And Kafka topic specified in configuration variable "incoming_topic" is created
      And Kafka topic specified in configuration variable "dead_letter_queue_topic" is created
      And Kafka topic specified in configuration variable "archive_results" is created
     When SHA extractor service is started
     Then SHA extractor service does not exit with an error code
      And SHA extractor service should be registered to topic "incoming_topic"


  Scenario: Check if SHA extractor is able to consume messages from Kafka
    Given SHA extractor service is started
      And Kafka broker is started
      And Kafka topic specified in configuration variable "incoming_topic" is created
      And Kafka topic specified in configuration variable "dead_letter_queue_topic" is created
      And Kafka topic specified in configuration variable "archive_results" is created
     When an event about new tarball being sent by Insights Operator is produced into "incoming_topic" topic
     Then SHA extractor should consume message about this event
      And this message should contains following attributes
          | Attribute    | Description                | Type         |
          | account      | account ID                 | unsigned int |
          | principal    | principal ID               | unsigned int |
          | size         | tarball size               | unsigned int |
          | url          | URL to S3                  | string       |
          | b64_identity | identity encoded by BASE64 | string       |
          | timestamp    | timestamp of event         | string       |
     When SHA extractor decode the b64_identity attribute
     Then structured information about user identity should be retrieved
      And that information should be represented in JSON format


  Scenario: Check if SHA extractor is able to consume messages from Kafka and then download tarball
    Given SHA extractor service is started
      And Kafka broker is started
      And Kafka topic specified in configuration variable "incoming_topic" is created
      And Kafka topic specified in configuration variable "dead_letter_queue_topic" is created
      And Kafka topic specified in configuration variable "archive_results" is created
     When an event about about new tarball being sent by Insights Operator is produced into "incoming_topic" topic
     Then SHA extractor should consume message about this event
      And this message should contains following attributes
          | Attribute    | Description                | Type         |
          | account      | account ID                 | unsigned int |
          | principal    | principal ID               | unsigned int |
          | size         | tarball size               | unsigned int |
          | url          | URL to S3                  | string       |
          | b64_identity | identity encoded by BASE64 | string       |
          | timestamp    | timestamp of event         | string       |
     When SHA extractor consume this message
      And SHA extractor retrieve the "url" attribute from the message
     Then SHA extractor should start downloading tarball from address taken from "url" attribute


  Scenario: Check if SHA extractor is able to consume messages from Kafka, download tarball, and take SHA images
    Given SHA extractor service is started
      And Kafka broker is started
      And Kafka topic specified in configuration variable "incoming_topic" is created
      And Kafka topic specified in configuration variable "dead_letter_queue_topic" is created
      And Kafka topic specified in configuration variable "archive_results" is created
     When new event about about new tarball being sent by Insights Operator is produced into "incoming_topic" topic
     Then SHA extractor should consume message about this event
      And this message should contains following attributes
          | Attribute    | Description                | Type         |
          | account      | account ID                 | unsigned int |
          | principal    | principal ID               | unsigned int |
          | size         | tarball size               | unsigned int |
          | url          | URL to S3                  | string       |
          | b64_identity | identity encoded by BASE64 | string       |
          | timestamp    | timestamp of event         | string       |
     When SHA extractor consume this message
     Then SHA extractor should take the URL attribute
      And SHA extractor should download tarball from given URL attribute
     When SHA extractor decompress the tarball
     Then SHA extractor needs to check if it contains file "config/workload_info.json"
     When that file is not found
     Then the tarball is not further processed
