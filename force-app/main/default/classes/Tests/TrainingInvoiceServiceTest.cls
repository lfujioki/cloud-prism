@IsTest
private class TrainingInvoiceServiceTest {

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

        TrainingProduct__c product1 = new TrainingProduct__c(Name = 'Product One', ProductPrice__c = 100);
        TrainingProduct__c product2 = new TrainingProduct__c(Name = 'Product Two', ProductPrice__c = 10);
        List<TrainingProduct__c> products = new List<TrainingProduct__c> {product1, product2};
        insert products;

        TrainingLineItem__c item1 = new TrainingLineItem__c();
        item1.Name = '1';
        item1.Training__c = training.Id;
        item1.TrainingProduct__c = products.get(0).Id;

        TrainingLineItem__c item2 = new TrainingLineItem__c();
        item2.Name = '2';
        item2.Training__c = training.Id;
        item2.TrainingProduct__c = products.get(1).Id;

        List<TrainingLineItem__c> items = new List<TrainingLineItem__c> {item1, item2};
        insert items;

        Contact contact = new Contact(LastName = 'Participant', CanBookForOthers__c = true, Email = 'e@mail.com');
        insert contact;

        Participant__c participant = new Participant__c(Contact__c = contact.Id, Training__c = training.Id);
        insert participant;

    }

    @IsTest
    static void afterInsertTrigger_UnitTest() {
        Participant__c participant = [SELECT Id, Training__c, Contact__c FROM Participant__c LIMIT 1];

        TrainingInvoice__c invoice = new TrainingInvoice__c();
        invoice.InvoiceDate__c = System.today();
        invoice.InvoiceId__c = '657c33e3c01b55ac1cfd6f59';
        invoice.Status__c = InvoicePostProcessingQueueable.INVOICE_STATUS_CREATED;
        invoice.Participant__c = participant.Id;
        invoice.Training__c = participant.Training__c;

        Test.startTest();
        insert invoice;
        Test.stopTest();

        List<TrainingInvoiceLineItem__c> invoiceItems = [
            SELECT Name, Invoice__c, TrainingProduct__c, Price__c, Tax__c
            FROM TrainingInvoiceLineItem__c
        ];

        Assert.areEqual(2, invoiceItems.size());

        for(TrainingInvoiceLineItem__c invoiceItem : invoiceItems) {
            Assert.areEqual(invoice.Id, invoiceItem.Invoice__c);
        }
    }

    @IsTest
    static void insertInvoiceLineItemsFromTrainingNullId_UnitTest() {
        Participant__c participant = [SELECT Id, Training__c, Contact__c FROM Participant__c LIMIT 1];

        TrainingInvoice__c invoice = new TrainingInvoice__c();
        invoice.InvoiceDate__c = System.today();
        invoice.InvoiceId__c = '657c33e3c01b55ac1cfd6f59';
        invoice.Status__c = InvoicePostProcessingQueueable.INVOICE_STATUS_CREATED;
        invoice.Participant__c = participant.Id;
        invoice.Training__c = participant.Training__c;
        List<TrainingInvoice__c> invoices = new List<TrainingInvoice__c> {invoice};

        Test.startTest();
        new TrainingInvoiceService().insertInvoiceLineItemsFromTraining(invoices, null);
        Test.stopTest();

        List<TrainingInvoiceLineItem__c> invoiceItems = [
            SELECT Name, Invoice__c, TrainingProduct__c, Price__c, Tax__c
            FROM TrainingInvoiceLineItem__c
        ];

        Assert.areEqual(0, invoiceItems.size());

        List<ErrorLog__c> errorLogs = [
            SELECT Id, ClassName__c, MethodName__c, ExceptionType__c, ExceptionMessage__c 
            FROM ErrorLog__c 
            WHERE ClassName__c = 'TrainingInvoiceService'
        ];

        Assert.areEqual(1, errorLogs.size());

        ErrorLog__c resultLog = errorLogs.get(0);
        Assert.areEqual('insertInvoiceLineItemsFromTraining', resultLog.MethodName__c);
        Assert.areEqual('TrainingInvoiceService', resultLog.ClassName__c);
        Assert.areEqual('System.DmlException', resultLog.ExceptionType__c);
        Assert.isTrue(resultLog.ExceptionMessage__c.contains('Required fields are missing: [Invoice__c]'));

        System.debug(resultLog.ExceptionMessage__c);
    }

}