public class RegistrationConfirmationQueueable implements Queueable, Database.AllowsCallouts {

    public virtual class RegistrationConfirmationQueueableException extends Exception {}
    public class PaymentLinkCalloutException extends RegistrationConfirmationQueueableException {}

    private List<Training__c> trainings;

    public RegistrationConfirmationQueueable(List<Training__c> trainings) {
        this.trainings = trainings;
    }

    /**
     * This method is part of the Participant registration confirmation process. It is called from the 
     * "ParticipantService" class. It sends the confirmation emails and updates each participant with 
     * their unique payment link.
     */
    public void execute(QueueableContext context) {
        List<Participant__c> participantsToUpdate = new List<Participant__c>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for(Training__c training : trainings) {
            for(Participant__c participant : training.Participants__r) {
                Logger logger = new Logger();
                String responseBody = '';
                String link = '';

                try {
                    responseBody = PaymentLinkCallout.doPaymentCalloutForParticipant(participant);
                    link = parsePaymentLink(responseBody);

                    if(responseBody == '') {
                        throw new PaymentLinkCalloutException();
                    }
                } catch(PaymentLinkCalloutException p) {
                    logger.logException(p);
                } catch(Exception e) {
                    logger.logException(e);
                }

                participant.PaymentLink__c = link;
                participantsToUpdate.add(participant);

                emails.add(EmailService.createParticipantConfirmationEmail(training, participant));
            }
        }

        if(!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }

        if(!participantsToUpdate.isEmpty()){
            update participantsToUpdate;
        }
    }

    /**
     * This method is part of the Participant registration confirmation process. It is called from the queueable 
     * class, "RegistrationConfirmationQueueable." It returns the payment link or an empty string if the expected 
     * data is not found.
     * 
     * @param responseBody  JSON body of response from API call
     */
    @TestVisible
    private String parsePaymentLink(String responseBody) {
        PaymentResponse paymentResponse = (PaymentResponse) JSON.deserialize(responseBody, PaymentResponse.class);

        if(paymentResponse.payer == null) {
            return '';
        }

        if(paymentResponse.payer.link == null) {
            return '';
        }

        return paymentResponse.payer.link;
    }

    public class PaymentResponse {
        public Payer payer;
    }

    public class Payer {
        public String link;
    }

}