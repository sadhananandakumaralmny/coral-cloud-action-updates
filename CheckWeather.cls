/**
 * CheckWeather - A Salesforce Apex class for checking weather at Coral Cloud Resorts
 * 
 * This class is designed to be used with Salesforce Flow Builder as an Invocable Action.
 * Users can provide a date and get weather information for that specific date.
 * 
 * [MODIFIED FROM ORIGINAL: Added comprehensive error handling, input validation, 
 * and graceful 404 error handling for dates too far in the future]
 */
public with sharing class CheckWeather {
    
    /**
     * @InvocableMethod - This annotation tells Salesforce that this method can be called from Flow Builder
     * The label and description appear in the Flow Builder interface for users to see
     * 
     * [MODIFIED FROM ORIGINAL: Added better error handling and 404 response management]
     */
    @InvocableMethod(
        label='Check Weather'
        description='Check weather at Coral Cloud Resorts at a specific date. The date must be in the future, not today or earlier.'
    )
    public static List<WeatherResponse> getWeather(
        List<WeatherRequest> requests  // Invocable methods always take a List as input, even for single requests
    ) {
        
        /*
         * INPUT VALIDATION SECTION
         * [ADDED: This entire validation section was added to prevent runtime errors]
         * 
         * In Apex, it's critical to validate inputs before processing them.
         * Without validation, the code could crash with null pointer exceptions.
         */
        
        // Check if the request list is null or empty
        // In Apex, you must check for null before calling methods like isEmpty()
        if (requests == null || requests.isEmpty()) {
            // IllegalArgumentException is a built-in Apex exception type for invalid inputs
            throw new IllegalArgumentException('Request list cannot be null or empty');
        }
        
        // Check if the first request in the list is null
        // Invocable methods process the first item in the list by convention
        if (requests[0] == null) {
            throw new IllegalArgumentException('Weather request cannot be null');
        }
        
        // Check if the date field is null
        // Date fields can be null in Apex, so we must validate them
        if (requests[0].dateToCheck == null) {
            throw new IllegalArgumentException('Date to check cannot be null');
        }
        
        /*
         * BUSINESS LOGIC VALIDATION
         * [MODIFIED FROM ORIGINAL: Removed strict future date validation to allow today's date]
         * Original code had no date validation at all
         */
        
        // Log the date being processed for debugging purposes
        // System.debug() writes to the Salesforce debug logs
        System.debug('Checking weather for date: ' + requests[0].dateToCheck);
        
        /*
         * MAIN PROCESSING SECTION WITH ERROR HANDLING
         * [MODIFIED FROM ORIGINAL: Added comprehensive try-catch block and 404 handling]
         */
        try {
            /*
             * DATE CONVERSION
             * [MODIFIED FROM ORIGINAL: Changed from unsafe casting to proper conversion]
             * Original code: Datetime dateToCheck = (Datetime) requests[0].dateToCheck;
             * This casting approach could cause runtime errors
             */
            
            // Convert Date to Datetime using Salesforce's built-in method
            // Time.newInstance(0, 0, 0, 0) creates midnight (00:00:00.000)
            Datetime dateToCheck = Datetime.newInstance(requests[0].dateToCheck, Time.newInstance(0, 0, 0, 0));
            System.debug('Converted to Datetime: ' + dateToCheck);

            /*
             * EXTERNAL SERVICE CALL
             * [UNCHANGED: This was in the original code]
             * WeatherService.getResortWeather() is an external service call that can fail
             */
            
            // Call the weather service - this makes an HTTP callout to get weather data
            WeatherService.Weather weather = WeatherService.getResortWeather(dateToCheck);
            System.debug('Weather service returned: ' + weather);
            
            /*
             * RESPONSE VALIDATION
             * [ADDED: Original code didn't check if the service returned null]
             */
            
            // Validate that the weather service returned data
            if (weather == null) {
                // Throw our custom exception (defined at the bottom of this class)
                throw new WeatherServiceException('Weather service returned null response');
            }

            /*
             * RESPONSE OBJECT CREATION
             * [MODIFIED FROM ORIGINAL: Extracted description building to separate method]
             * Original code built the description inline, making it hard to test
             */
            
            // Create the response object that will be returned to Flow Builder
            WeatherResponse response = new WeatherResponse();
            
            // Set temperature values from the weather service response
            response.minTemperature = weather.minTemperatureC;
            response.maxTemperature = weather.maxTemperatureC;
            
            // Use helper method to build description (defined below)
            response.temperatureDescription = buildTemperatureDescription(weather);
            
            // Log the response for debugging
            System.debug('Created response: Min=' + response.minTemperature + ', Max=' + response.maxTemperature);
            
            /*
             * RETURN STATEMENT
             * [UNCHANGED: This was in the original code]
             * Invocable methods must return a List, even for single responses
             */
            return new List<WeatherResponse>{ response };
            
        } catch (Exception e) {
            /*
             * ERROR HANDLING SECTION
             * [ADDED: This entire catch block was added for better error management]
             * Original code had no error handling - any failure would crash the Flow
             */
            
            // Log all errors for debugging - this helps with troubleshooting
            System.debug(LoggingLevel.ERROR, 'Error in CheckWeather.getWeather: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            
            /*
             * SPECIAL HANDLING FOR 404 ERRORS
             * [ADDED: Custom logic to handle dates too far in the future gracefully]
             * Instead of showing a technical error to users, show a friendly message
             */
            
            // Check if this is a 404 error (date too far in future or past)
            if (e.getMessage().contains('404') || e.getMessage().contains('Not Found')) {
                System.debug('Detected 404 error - date too far in future, returning custom message');
                
                /*
                 * GRACEFUL 404 RESPONSE
                 * [ADDED: Return friendly message instead of crashing]
                 * This provides a better user experience in Flow Builder
                 */
                
                // Create a response with a user-friendly message
                WeatherResponse response = new WeatherResponse();
                response.minTemperature = null;  // Set to null since no data available
                response.maxTemperature = null;  // Set to null since no data available
                response.temperatureDescription = 'I am sorry my forecasting abilities do not go out that far.';
                
                return new List<WeatherResponse>{ response };
            }
            
            /*
             * HANDLE OTHER ERRORS
             * [ADDED: Re-throw other errors with more context]
             * This helps with debugging while still providing meaningful error messages
             */
            
            // For non-404 errors, re-throw with additional context
            throw new WeatherServiceException('Failed to retrieve weather data: ' + e.getMessage(), e);
        }
    }
    
    /*
     * HELPER METHOD FOR BUILDING DESCRIPTIONS
     * [ADDED: Extracted from main method to improve testability and code organization]
     * @TestVisible makes this method accessible to test classes
     */
    
    /**
     * Builds a user-friendly temperature description string
     * @param weather The weather data from the service
     * @return A formatted description string for display to users
     */
    @TestVisible
    private static String buildTemperatureDescription(WeatherService.Weather weather) {
        // Handle null input gracefully
        if (weather == null) {
            return 'Weather data unavailable';
        }
        
        /*
         * STRING CONCATENATION
         * [MODIFIED FROM ORIGINAL: Moved this logic to separate method]
         * This builds the user-friendly description that appears in Flow Builder
         */
        return 'Temperatures will be between ' +
               weather.minTemperatureC +
               '°C (' +
               weather.minTemperatureF +
               '°F) and ' +
               weather.maxTemperatureC +
               '°C (' +
               weather.maxTemperatureF +
               '°F) at Coral Cloud Resorts.';
    }

    /*
     * INNER CLASS: WeatherRequest
     * [UNCHANGED: This was in the original code]
     * 
     * Inner classes in Apex are defined inside other classes.
     * This represents the input data structure for the Invocable method.
     */
    
    /**
     * Represents a weather request with the date to check
     * This class structure is used by Flow Builder to collect input from users
     */
    public class WeatherRequest {
        /**
         * @InvocableVariable annotation makes this field available in Flow Builder
         * required=true means Flow Builder will require users to provide this value
         * description appears as help text in Flow Builder
         */
        @InvocableVariable(
            required=true
            description='Date for which we want to check the temperature. The variable needs to be an Apex Date type with format yyyy-MM-dd.'
        )
        public Date dateToCheck;  // Date type stores just the date (no time component)
    }

    /*
     * INNER CLASS: WeatherResponse  
     * [UNCHANGED: This was in the original code]
     * 
     * This represents the output data structure returned to Flow Builder.
     * Users can access these fields in subsequent Flow steps.
     */
    
    /**
     * Represents the weather response with temperature data and description
     * Flow Builder can access these fields after the method executes
     */
    public class WeatherResponse {
        /**
         * @InvocableVariable makes these fields available as outputs in Flow Builder
         * description appears as help text when users select these fields
         */
        
        @InvocableVariable(
            description='Minimum temperature in Celsius at Coral Cloud Resorts location for the provided date'
        )
        public Decimal minTemperature;  // Decimal type for precise temperature values
        
        @InvocableVariable(
            description='Maximum temperature in Celsius at Coral Cloud Resorts location for the provided date'
        )
        public Decimal maxTemperature;  // Decimal type for precise temperature values
        
        @InvocableVariable(
            description='Description of temperatures at Coral Cloud Resorts location for the provided date'
        )
        public String temperatureDescription;  // String type for user-friendly text
    }
    
    /*
     * CUSTOM EXCEPTION CLASS
     * [ADDED: This entire class was added for better error handling]
     * 
     * Custom exceptions in Apex extend the base Exception class.
     * This provides more specific error handling for weather service issues.
     */
    
    /**
     * Custom exception for weather service specific errors
     * Extends the built-in Exception class to provide more specific error handling
     */
    public class WeatherServiceException extends Exception {
        /*
         * Exception classes in Apex automatically inherit constructors from the base Exception class:
         * - WeatherServiceException(String message)
         * - WeatherServiceException(String message, Exception cause)
         * 
         * No additional code needed - Apex provides the functionality automatically
         */
    }
}
