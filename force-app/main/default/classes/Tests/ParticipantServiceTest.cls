@IsTest
public with sharing class ParticipantServiceTest {

    @TestSetup
    static void setup() {
        Restaurant__c restaurant = new Restaurant__c();
        restaurant.Name = 'Tam O\'Shanter';
        restaurant.CommissionRate__c = 15;
        restaurant.AverageMealCost__c = 55;
        insert restaurant;

        Training__c training = new Training__c();
        training.Name = 'Test Trigger Training';
        training.Restaurant__c = restaurant.Id;
        training.StartDate__c = System.today().addMonths(1);
        training.EndDate__c = System.today().addMonths(1);
        training.TotalPrice__c = 120.00;
        training.TotalTax__c = 22.80;
        insert training;

        Contact contact1 = new Contact(LastName = 'Participant-One', CanBookForOthers__c = true, Email = 'e@mail.com');
        Contact contact2 = new Contact(LastName = 'Participant-Two', CanBookForOthers__c = false, Email = 'e@mail.com');
        List<Contact> contacts = new List<Contact> {contact1, contact2};
        insert contacts;

        Participant__c participant1 = new Participant__c(Contact__c = contact1.Id, Training__c = training.Id);
        Participant__c participant2 = new Participant__c(Contact__c = contact2.Id, Training__c = training.Id);
        List<Participant__c> participants = new List<Participant__c> {participant1, participant2};
        insert participants;

        TrainingInvoice__c invoice = new TrainingInvoice__c();
        invoice.InvoiceDate__c = System.today();
        invoice.InvoiceId__c = '657c33e3c01b55ac1cfd6f59';
        invoice.Status__c = InvoicePostProcessingQueueable.INVOICE_STATUS_CREATED;
        invoice.Participant__c = participant1.Id;
        invoice.Training__c = participant1.Training__c;
        insert invoice;
    }

    @IsTest
    static void preventDuplicateParticipantOnTrainings_lazy() {
        Training__c training = [SELECT Id, Name FROM Training__c LIMIT 1];
        List<Contact> contacts = [SELECT Id, LastName, CanBookForOthers__c FROM Contact];
        Contact contact1 = contacts.get(0);
        Contact contact2 = contacts.get(1);

        Participant__c dupParticipant1 = new Participant__c(Contact__c = contact1.Id, Training__c = training.Id);
        Participant__c dupParticipant2 = new Participant__c(Contact__c = contact2.Id, Training__c = training.Id);
        List<Participant__c> dupParticipants = new List<Participant__c> {dupParticipant1, dupParticipant2};

        try {
            Test.startTest();
            insert dupParticipants;
            Test.stopTest();

            Assert.fail();
        } catch(System.DmlException e) {
            Assert.isTrue(true);
        }
    }

    @IsTest
    static void recalculateRestaurantCommission_UnitTest() {
        Integer expectedParticipantsSize = 4;
        Training__c training = [SELECT Id, Name FROM Training__c LIMIT 1];
        List<Contact> contacts = [SELECT Id, LastName, CanBookForOthers__c FROM Contact];
        contacts.get(0).CanBookForOthers__c = true;
        contacts.get(1).CanBookForOthers__c = true;
        update contacts;

        Participant__c participant1 = new Participant__c();
        participant1.Contact__c = contacts.get(0).Id;
        participant1.Training__c = training.Id;

        Participant__c participant2 = new Participant__c();
        participant2.Contact__c = contacts.get(1).Id;
        participant2.Training__c = training.Id;

        List<Participant__c> participants = new List<Participant__c> {participant1, participant2};
        insert participants;

        Test.startTest();
        new ParticipantService().recalculateCommissionOnTrainings(participants, null);
        Test.stopTest();

        List<Training__c> trainingsUpdated = [
            SELECT Id, Restaurant__c, RestaurantCommission__c, (SELECT Id FROM Participants__r)
            FROM Training__c 
            WHERE Id = :training.Id
            LIMIT 1
        ];

        Training__c result = trainingsUpdated.get(0);
        Assert.areEqual(expectedParticipantsSize, result.Participants__r.size());
        Assert.areEqual(26.40, result.RestaurantCommission__c);
    }

    @IsTest
    static void recalculateRestaurantCommissionOnDelete_UnitTest() {
        Integer expectedParticipantsSize = 1;
        List<Training__c> training = [SELECT Id, (SELECT Id FROM Participants__r) FROM Training__c];
        Participant__c participant = training.get(0).Participants__r.get(0);

        Test.startTest();
        delete participant;
        Test.stopTest();

        List<Training__c> trainingsUpdated = [
            SELECT Id, RestaurantCommission__c, (SELECT Id FROM Participants__r) 
            FROM Training__c
        ];

        Training__c result = trainingsUpdated.get(0);
        Assert.areEqual(expectedParticipantsSize, result.Participants__r.size());
        Assert.areEqual(6.6, result.RestaurantCommission__c);
    }

    @IsTest
    static void enqueueRegistrationConfirmationJob_UnitTest() {     
        List<Participant__c> participants = [SELECT Id, Training__c, Contact__c FROM Participant__c];

        Test.startTest();
        new ParticipantService().enqueueRegistrationConfirmationJob(participants, null);
        Test.stopTest();

        List<AsyncApexJob> job = [SELECT Id, Status, JobType, ApexClass.Name FROM AsyncApexJob];

        AsyncApexJob result = job.get(0);
        Assert.areEqual('Completed', result.Status);
        Assert.areEqual('Queueable', result.JobType);
        Assert.areEqual('RegistrationConfirmationQueueable', result.ApexClass.Name);
    }

    @IsTest
    static void initiateRefundOrder_UnitTest() {
        Test.setMock(HttpCalloutMock.class, new RefundCalloutHttpCalloutMock());

        Participant__c participant = [SELECT Id, Training__c, Contact__c FROM Participant__c LIMIT 1];

        Test.startTest();
        String invoiceName = new ParticipantService().initiateRefundOrder(participant.Id, 'Billing Error');
        Test.stopTest();

        Assert.isNotNull(invoiceName);

        List<TrainingRefund__c> refunds = [SELECT Status__c, RefundId__c FROM TrainingRefund__c];

        Assert.areEqual(1, refunds.size());

        TrainingRefund__c refund = refunds.get(0);
        Assert.areEqual(RefundPostProcessingQueueable.REFUND_STATUS_FAILED, refund.Status__c);
        Assert.isNotNull(refund.RefundId__c);

        List<AsyncApexJob> jobs = [SELECT Id, Status, JobType FROM AsyncApexJob WHERE ApexClass.Name = 'RefundPollingQueueable'];

        Assert.areEqual(1, jobs.size());

        AsyncApexJob job = jobs.get(0);
        Assert.areEqual('Completed', job.Status);
        Assert.areEqual('Queueable', job.JobType);
    }

    // @IsTest
    // static void updateParticipantPaymentLink_UnitTest() {
    //     Test.setMock(HttpCalloutMock.class, new PaymentLinkCalloutHttpCalloutMock());

    //     Contact contact = [SELECT Id FROM Contact LIMIT 1];
    //     Training__c training = [SELECT Id FROM Training__c LIMIT 1];

    //     Participant__c participant = new Participant__c(Contact__c = contact.Id, Training__c = training.Id);

    //     Test.startTest();
    //     insert participant;
    //     Test.stopTest();

    //     Participant__c updatedParticipant = [SELECT Id, PaymentLink__c FROM Participant__c LIMIT 1];
    //     Assert.areEqual(PaymentLinkCalloutHttpCalloutMock.PAYMENT_LINK, updatedParticipant.PaymentLink__c);
    // }

    @IsTest
    static void queryTrainingsWithParticipantsById_UnitTest() {
        Integer expectedParticipantsSize = 3;
        Training__c training = [SELECT Id, Name FROM Training__c];

        Contact newContact = new Contact(LastName = 'New-Student', CanBookForOthers__c = true, Email = 'new@mail.com');
        insert newContact;

        Participant__c newParticipant = new Participant__c(Contact__c = newContact.Id, Training__c = training.Id);
        insert newParticipant;

        Set<Id> trainingIds = new Set<Id>();
        trainingIds.add(training.Id);

        Test.startTest();
        List<Training__c> trainings = TrainingQueries.queryTrainingsWithParticipantsById(trainingIds);
        Test.stopTest();

        Training__c result = trainings.get(0);
        Assert.areEqual(expectedParticipantsSize, result.Participants__r.size());
        for(Participant__c participant : result.Participants__r) {
            Assert.areEqual(training.Id, participant.Training__c);
        }
    }

    @IsTest
    static void queryContactsOfParticipantsById_UnitTest() {
        Training__c training = [SELECT Id, Name FROM Training__c];

        Contact newContact = new Contact(LastName = 'New-Student', CanBookForOthers__c = true, Email = 'new@mail.com');
        insert newContact;

        Participant__c newParticipant = new Participant__c(Contact__c = newContact.Id, Training__c = training.Id);
        insert newParticipant;

        Set<Id> contactIds = new Set<Id>();
        contactIds.add(newParticipant.Contact__c);

        Test.startTest();
        List<Contact> contacts = ContactQueries.queryContactsOfParticipantsById(contactIds);
        Test.stopTest();

        Contact result = contacts.get(0);
        Assert.areEqual(newContact.Id, result.Id);
        Assert.areEqual(newContact.CanBookForOthers__c, result.CanBookForOthers__c);
    }

    @IsTest
    static void queryTrainingsForNewParticipantsByParticipantIds_UnitTest() {
        Integer expectedParticipantSize = 1;
        Training__c training = [SELECT Id, Name FROM Training__c];

        Contact newContact = new Contact(LastName = 'New-Student', CanBookForOthers__c = true, Email = 'new@mail.com');
        insert newContact;

        Participant__c newParticipant = new Participant__c(Contact__c = newContact.Id, Training__c = training.Id);
        insert newParticipant;

        Set<Id> trainingIds = new Set<Id>();
        trainingIds.add(training.Id);

        Set<Id> participantIds = new Set<Id>();
        participantIds.add(newParticipant.Id);

        Test.startTest();
        List<Training__c> trainings = TrainingQueries.queryTrainingsForNewParticipantsByParticipantIds(participantIds);
        Test.stopTest();

        Training__c result = trainings.get(0);
        Assert.areEqual(expectedParticipantSize, result.Participants__r.size());
        Assert.areEqual(newContact.LastName, result.Participants__r.get(0).Contact__r.LastName);
    }


    @IsTest
    static void queryInvoiceByParticipantId_UnitTest() {
        Participant__c participant = [SELECT Id, Name FROM Participant__c LIMIT 1];

        Test.startTest();
        TrainingInvoice__c invoice = InvoiceQueries.queryInvoiceByParticipantId(participant.Id);
        Test.stopTest();

        Assert.areEqual('657c33e3c01b55ac1cfd6f59', invoice.InvoiceId__c);
        Assert.areEqual(participant.Id, invoice.Participant__c);
    }

}