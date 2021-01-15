*&---------------------------------------------------------------------*
*& Report YSTSTF00
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT yhdb_customers.

CLASS app DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS main.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.

NEW app( )->main( ).

CLASS app IMPLEMENTATION.

  METHOD main.

    TYPES: BEGIN OF ty_customers,
             post_code  TYPE string,
             sum_amount TYPE p LENGTH 10 DECIMALS 2,
           END OF ty_customers.

    DATA customers TYPE STANDARD TABLE OF ty_customers.

    TRY.
        DATA(sql) = NEW cl_sql_statement( con_ref = cl_sql_connection=>get_connection( 'HANACBA' ) ).
        DATA(statement) = |select top 10 "postCode", sum("amount") as sumAmount from "CBA_FUW"."CUSTOMERS" group by "postCode" order by sumAmount desc;|.

        DATA(result) = sql->execute_query( statement ).

        result->set_param_table( REF #( customers ) ).
        result->next_package( ).

        cl_demo_output=>display( customers ).

      CATCH cx_sql_exception INTO DATA(lcx).
        cl_demo_output=>display( lcx->get_text( ) ).

      CATCH cx_parameter_invalid INTO DATA(lcx_parameter).    "
        cl_demo_output=>display( lcx_parameter->get_text( ) ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
