*&---------------------------------------------------------------------*
*& Report YSTSTF00
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT yhdb_spatial_display_points.

CLASS app DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS main.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.

NEW app( )->main( ).

CLASS app IMPLEMENTATION.

  METHOD main.

    TYPES: BEGIN OF ty_coordinate,
             longitude TYPE p LENGTH 16 DECIMALS 13,
             latitude  TYPE p LENGTH 16 DECIMALS 13,
           END OF ty_coordinate.

    DATA coordinates TYPE STANDARD TABLE OF ty_coordinate.

    TRY.
        DATA(sql) = NEW cl_sql_statement( con_ref = cl_sql_connection=>get_connection( 'HANACBA' ) ).
        DATA(statement) = |select point.ST_X(), point.ST_Y() from CBA_FUW."RandomPoints"|.
*        DATA(statement) = |select point.ST_X(), point.ST_Y() from CBA_FUW."RandomPoints"| &&
*                          |  where point.ST_Distance( NEW ST_Point( 'POINT( 8.6439 49.292783 )',4326 ), 'meter' ) <= 100;|.
        DATA(result) = sql->execute_query( statement ).
        result->set_param_table( REF #( coordinates ) ).
        result->next_package( ).

        DATA(geojson) = NEW zcl_geojson( ).

        LOOP AT coordinates REFERENCE INTO DATA(coordinate).

          DATA(point) = geojson->get_new_point(
            i_latitude = coordinate->latitude
            i_longitude = coordinate->longitude
          ).

          geojson->add_feature( point ).
        ENDLOOP.

        cl_demo_output=>display_html( NEW zcl_geojson_leafletjs( )->get_html( geojson->get_json( ) ) ).

      CATCH cx_sql_exception INTO DATA(lcx2).
        cl_demo_output=>display( lcx2->get_text( ) ).

      CATCH cx_parameter_invalid INTO DATA(lcx_parameter).    "
        cl_demo_output=>display( lcx_parameter->get_text( ) ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
