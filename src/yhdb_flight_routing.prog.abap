*&---------------------------------------------------------------------*
*& Report YSTSTF00
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT yhdb_flight_routing.

CLASS app DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS main.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.

NEW app( )->main( ).

CLASS app IMPLEMENTATION.

  METHOD main.

    TYPES: BEGIN OF ty_routing,
             segment                TYPE i,
             airportcodeorigin      TYPE c LENGTH 3,
             airportcodedestination TYPE c LENGTH 3,
             airlinename            TYPE string,
             distance               TYPE i,
             duration               TYPE i,
           END OF ty_routing.

    DATA routings TYPE STANDARD TABLE OF ty_routing.

    TRY.
        DATA(sql) = NEW cl_sql_statement( con_ref = cl_sql_connection=>get_connection( 'HANACBA' ) ).
        DATA(statement) = |CALL "CBA_TRAVEL"."TripRoutingSPWSimple"( '', 'NTE', 'PDX', NULL );|.

        DATA(result) = sql->execute_query( statement ).

        result->set_param_table( REF #( routings ) ).
        result->next_package( ).

        cl_demo_output=>write( routings ).

        CLEAR routings.
        statement = |CALL "CBA_TRAVEL"."TripRoutingSPWSimple"( 'distance', 'NTE', 'PDX', NULL );|.
        result = sql->execute_query( statement ).

        result->set_param_table( REF #( routings ) ).
        result->next_package( ).

        cl_demo_output=>write( routings ).

        CLEAR routings.
        statement = |CALL "CBA_TRAVEL"."TripRoutingSPWSimple"( 'duration', 'NTE', 'PDX', NULL );|.
        result = sql->execute_query( statement ).

        result->set_param_table( REF #( routings ) ).
        result->next_package( ).

        cl_demo_output=>write( routings ).


        cl_demo_output=>display( ).

      CATCH cx_sql_exception INTO DATA(lcx).
        cl_demo_output=>display( lcx->get_text( ) ).

      CATCH cx_parameter_invalid INTO DATA(lcx_parameter).    "
        cl_demo_output=>display( lcx_parameter->get_text( ) ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
