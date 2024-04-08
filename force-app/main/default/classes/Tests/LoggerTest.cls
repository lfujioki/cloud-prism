@IsTest
public with sharing class LoggerTest {

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
        insert training;

        TrainingInvoice__c invoice = new TrainingInvoice__c();
        invoice.InvoiceDate__c = System.today();
        invoice.InvoiceId__c = '657c33e3c01b55ac1cfd6f59';
        invoice.Status__c = InvoicePostProcessingQueueable.INVOICE_STATUS_CREATED;
        invoice.Training__c = training.Id;
        insert invoice;

        TrainingRefund__c refund = new TrainingRefund__c();
        refund.TrainingInvoice__r = new TrainingInvoice__c(InvoiceId__c = invoice.InvoiceId__c);
        refund.Amount__c = 190;
        refund.Reason__c = 'Technical Issues';
        refund.RefundDate__c = System.today();
        refund.Status__c = ParticipantService.REFUND_STATUS_PENDING;
        refund.RefundId__c = RefundCalloutHttpCalloutMock.REFUND_RESPONSE_ID;
        insert refund;
    }

    @IsTest
    static void logException_UnitTest() {
        try {
            Participant__c participant = [SELECT Id FROM Participant__c WHERE Id = NULL];
        } catch(Exception e) {
            Logger logger = new Logger();

            Test.startTest();
            logger.logException(e);
            Test.stopTest();
        }

        ErrorLog__c insertedLog = [SELECT Id, ClassName__c, MethodName__c, LineNumber__c FROM ErrorLog__c LIMIT 1];

        Assert.isTrue(insertedLog.ClassName__c.contains('LoggerTest'));
        Assert.isTrue(insertedLog.MethodName__c.contains('logException_UnitTest'));
        Assert.areEqual(11, insertedLog.LineNumber__c);
    }

    @IsTest
    static void logERPException_UnitTest() {
        try {
            Participant__c participant = [SELECT Id FROM Participant__c WHERE Id = NULL];
        } catch(Exception e) {
            Logger logger = new Logger();

            Test.startTest();
            logger.logERPCalloutException(e);
            Test.stopTest();
        }

        ErrorLog__c insertedLog = [SELECT Id, ClassName__c, MethodName__c, Comments__c FROM ErrorLog__c LIMIT 1];

        Assert.isTrue(insertedLog.ClassName__c.contains('LoggerTest'));
        Assert.isTrue(insertedLog.MethodName__c.contains('logERPException_UnitTest'));
        Assert.isTrue(insertedLog.Comments__c.contains('Participant JSON or ERP Id string was empty'));
    }

    @IsTest
    static void logRefundOrderFailed_UnitTest() {
        TrainingRefund__c refund = [SELECT Name FROM TrainingRefund__c];

        try {
            Participant__c participant = [SELECT Id FROM Participant__c WHERE Id = NULL];
        } catch(Exception e) {
            Logger logger = new Logger();

            Test.startTest();
            logger.logRefundOrderFailed(refund);
            Test.stopTest();
        }

        ErrorLog__c insertedLog = [
            SELECT Id, ClassName__c, ExceptionType__c, Important__c, ExceptionMessage__c 
            FROM ErrorLog__c
        ];

        Assert.isTrue(insertedLog.ClassName__c.contains('RefundPostProcessingQueueable'));
        Assert.isTrue(insertedLog.ExceptionType__c.contains('Refund Order Failed'));
        Assert.isTrue(insertedLog.Important__c);

        TrainingRefund__c insertedRefund = [SELECT Name FROM TrainingRefund__c];

        Assert.isTrue(insertedLog.ExceptionMessage__c.contains(refund.Name));

    }

}