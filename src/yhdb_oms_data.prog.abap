*&---------------------------------------------------------------------*
*& Report yhdb_oms_data
*&---------------------------------------------------------------------*
*& Precondition:
*& Fill HANA DB with OMS shape files from https://www.geofabrik.de/
*& see https://developers.sap.com/tutorials/hana-cloud-trial-qgis-2.html
*&
*&---------------------------------------------------------------------*
REPORT yhdb_oms_data.

PARAMETERS p_place TYPE c LENGTH 50 LOWER CASE OBLIGATORY DEFAULT 'Walldorf'.
PARAMETERS p_bench RADIOBUTTON GROUP g1.
PARAMETERS p_post RADIOBUTTON GROUP g1.
PARAMETERS p_waste RADIOBUTTON GROUP g1.
PARAMETERS p_range TYPE i DEFAULT 1000.

CLASS lcl_app DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS main.
  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.

NEW lcl_app( )->main( ).

CLASS lcl_app IMPLEMENTATION.

  METHOD main.

    TYPES: BEGIN OF ty_point_of_interest,
             id        TYPE i,
             longitude TYPE p LENGTH 16 DECIMALS 13,
             latitude  TYPE p LENGTH 16 DECIMALS 13,
           END OF ty_point_of_interest.

    TYPES: BEGIN OF ty_place,
             id        TYPE i,
             longitude TYPE p LENGTH 16 DECIMALS 13,
             latitude  TYPE p LENGTH 16 DECIMALS 13,
           END OF ty_place.

    DATA places TYPE STANDARD TABLE OF ty_place.
    DATA pois TYPE STANDARD TABLE OF ty_point_of_interest.

    TRY.

        DATA(sql) = NEW cl_sql_statement( con_ref = cl_sql_connection=>get_connection( 'PODMAN' ) ).

        DATA(statement) = |SELECT "id", "geom".ST_X(), "geom".ST_Y() FROM qgis."gis_osm_places" where "name" = '{ p_place }';|.

        DATA(result) = sql->execute_query( statement ).
        result->set_param_table( REF #( places ) ).
        result->next_package( ).

        DATA(geojson) = NEW zcl_geojson( ).

        DATA(place) = REF #( places[ 1 ] ).

        DATA(point) = geojson->get_new_point(
          i_latitude = place->latitude
          i_longitude = place->longitude
        ).
        point->set_properties( i_popup_content = CONV #( p_place )
                               i_fill_color    = '#ff8888'
                               i_color         = '#ff0000' ).

        geojson->add_feature( point ).

        statement = |SELECT pois."id", pois."geom".ST_X(), pois."geom".ST_Y()| &&
                    |   FROM qgis."gis_osm_places" place| &&
                    |   INNER JOIN QGIS."gis_osm_pois" pois| &&
                    |   on pois."fclass" = '{ COND string( WHEN p_bench = abap_true THEN 'bench'
                                                           WHEN p_post  = abap_true THEN 'post_box'
                                                           WHEN p_waste = abap_true THEN 'waste_basket' ) }'| &&
                    |   and pois."geom".ST_Distance(place."geom") < { p_range }| &&
                    |   where place."id" = '{ place->id }';|.

        result = sql->execute_query( statement ).
        result->set_param_table( REF #( pois ) ).
        result->next_package( ).

        LOOP AT pois REFERENCE INTO DATA(coordinate).

          point = geojson->get_new_point(
            i_latitude = coordinate->latitude
            i_longitude = coordinate->longitude
          ).

          point->set_properties(
              i_radius = 4
              i_fill_color    = '#8888ff'
              i_color         = '#0000ff'
              i_popup_content = COND string( WHEN p_bench = abap_true THEN 'bench'
                                             WHEN p_post  = abap_true THEN 'post_box'
                                             WHEN p_waste = abap_true THEN 'waste_basket' ) ).
          geojson->add_feature( point ).
        ENDLOOP.

        cl_demo_output=>display_html( NEW zcl_geojson_leafletjs( )->get_html(
          i_json = geojson->get_json( )
          i_use_circle_markers = abap_true ) ).

      CATCH cx_sy_itab_line_not_found.
        MESSAGE 'Place not found' TYPE 'I' ##no_text.

      CATCH cx_sql_exception INTO DATA(lcx).
        cl_demo_output=>display( lcx->get_text( ) ).

      CATCH cx_parameter_invalid INTO DATA(lcx_parameter).    "
        cl_demo_output=>display( lcx_parameter->get_text( ) ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
