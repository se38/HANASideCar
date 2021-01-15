*&---------------------------------------------------------------------*
*& Report YSTSTF00
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT yhdb_spatial_create_points.

CLASS app DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS main.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.

NEW app( )->main( ).

CLASS app IMPLEMENTATION.

  METHOD main.

*CREATE COLUMN TABLE CBA_FUW.RandomPoints
*(
*  ShapeID NVARCHAR(50),
*  Point ST_Point(4326)                 <--- WGS84 - SRID 4326 The WGS84 standard provides a spheroidal reference surface for the Earth.
*);
*

    DATA n1 TYPE n LENGTH 6.
    DATA n2 TYPE n LENGTH 6.
    DATA(seed1) = CONV i( sy-timlo ).
    DATA(seed2) = seed1 + 1.

    DATA(rnd1) = cl_abap_random_int=>create(
                       seed           = seed1
                       min            = 291300
                       max            = 294904
                     ).

    DATA(rnd2) = cl_abap_random_int=>create(
                       seed           = seed2
                       min            = 635498
                       max            = 645261
                     ).


    TYPES: BEGIN OF ty_coordinate,
             longitude TYPE p LENGTH 16 DECIMALS 13,
             latitude  TYPE p LENGTH 16 DECIMALS 13,
           END OF ty_coordinate.

    DATA coordinates TYPE STANDARD TABLE OF ty_coordinate.

    DO 200 TIMES.

      TRY.
          n1 = rnd1->get_next( ).
          n2 = rnd2->get_next( ).

          INSERT VALUE ty_coordinate( longitude = CONV #( |8.{ n2 }| ) latitude = CONV #( |49.{ n1 }| ) ) INTO TABLE coordinates.

        CATCH cx_abap_random INTO DATA(lcx).
          WRITE:/ lcx->get_text( ).

      ENDTRY.
    ENDDO.

    TRY.
        DATA(sql) = NEW cl_sql_statement( con_ref = cl_sql_connection=>get_connection( 'HANACBA' ) ).

        DATA shape_id TYPE i.

        LOOP AT coordinates REFERENCE INTO DATA(coordinate).
          shape_id = shape_id + 1.

          DATA(statement) = |INSERT INTO "CBA_FUW"."RandomPoints" VALUES({ shape_id },  NEW ST_POINT('POINT({ coordinate->longitude } { coordinate->latitude })',4326));|.
          DATA(result) = sql->execute_update( statement ).
        ENDLOOP.

      CATCH cx_sql_exception INTO DATA(lcx2).
        cl_demo_output=>display( lcx2->get_text( ) ).

      CATCH cx_parameter_invalid INTO DATA(lcx_parameter).    "
        cl_demo_output=>display( lcx_parameter->get_text( ) ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
