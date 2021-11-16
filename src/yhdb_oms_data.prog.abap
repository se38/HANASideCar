*&---------------------------------------------------------------------*
*& Report yhdb_oms_data
*&---------------------------------------------------------------------*
*& Precondition:
*& Fill HANA DB with OMS shape files from https://www.geofabrik.de/
*& see https://developers.sap.com/tutorials/hana-cloud-trial-qgis-2.html
*&
*&---------------------------------------------------------------------*
REPORT yhdb_oms_data.

TABLES zhdb_oms_screen_s.       "for screen 9000
DATA : container    TYPE REF TO cl_gui_custom_container,
       html_control TYPE REF TO cl_gui_html_viewer.

CLASS lcl_app DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS main.
    METHODS status_9000.
    METHODS user_command_9000.

  PRIVATE SECTION.
    TYPES tt_html_table TYPE STANDARD TABLE OF char1024 WITH EMPTY KEY.

    DATA _connection TYPE REF TO cl_sql_connection.

    METHODS fill_drop_down_with_types
      RAISING cx_sql_exception.

    METHODS get_poi_types
      RETURNING VALUE(r_result) TYPE vrm_values
      RAISING   cx_sql_exception.

    METHODS display_pois.

    METHODS get_pois_string
      RETURNING VALUE(r_result) TYPE string.

    METHODS string_to_table
      IMPORTING i_html_string   TYPE string
      RETURNING VALUE(r_result) TYPE tt_html_table.

ENDCLASS.

DATA(g_app) = NEW lcl_app( ).
g_app->main( ).

CLASS lcl_app IMPLEMENTATION.


  METHOD status_9000.

    IF sy-pfkey <> '9000'.
      SET PF-STATUS '9000'.
      SET TITLEBAR '9000'.

      TRY.
          fill_drop_down_with_types( ).

          zhdb_oms_screen_s-place = 'Walldorf'.
          zhdb_oms_screen_s-poi_type = 'bench'.
          zhdb_oms_screen_s-range = 1000.

          container = NEW #( 'CCCONTAINER' ).
          html_control = NEW #( container ).

        CATCH cx_sql_exception INTO DATA(lcx).
          MESSAGE lcx TYPE 'I'.
      ENDTRY.

    ENDIF.

  ENDMETHOD.

  METHOD user_command_9000.

    DATA(ucomm) = sy-ucomm.
    CLEAR sy-ucomm.

    CASE ucomm.
      WHEN 'BACK' OR 'EXIT' or 'CANCEL'.
        LEAVE PROGRAM.
      WHEN 'ENTER' OR 'REDRAW'.
        display_pois( ).

    ENDCASE.

  ENDMETHOD.

  METHOD main.

    TRY.
        _connection = cl_sql_connection=>get_connection( 'PODMAN' ).
        CALL SCREEN 9000.

      CATCH cx_sql_exception INTO DATA(lcx).
        MESSAGE lcx TYPE 'E'.
    ENDTRY.

  ENDMETHOD.


  METHOD fill_drop_down_with_types.

    DATA(values) =  get_poi_types( ).

    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id     = 'ZHDB_OMS_SCREEN_S-POI_TYPE'                 " Name of Value Set
        values = values
      EXCEPTIONS
        OTHERS = 0.

  ENDMETHOD.


  METHOD get_poi_types.

    TYPES: BEGIN OF t_poi_type,
             fclass TYPE string,
           END OF t_poi_type.

    DATA poi_types TYPE STANDARD TABLE OF t_poi_type WITH EMPTY KEY.

    DATA(sql) = NEW cl_sql_statement( con_ref = _connection ).
    DATA(result) = sql->execute_query( 'SELECT DISTINCT poi."fclass" FROM QGIS."gis_osm_pois" poi' ).
    result->set_param_table( REF #( poi_types ) ).
    result->next_package( ).

    r_result = VALUE #( FOR poi_type IN poi_types ( key = poi_type-fclass text = poi_type-fclass ) ).

  ENDMETHOD.


  METHOD display_pois.

    DATA(html_string) = get_pois_string( ).
    DATA(html_table) = string_to_table( html_string ).

    DATA url TYPE c LENGTH 1024.

    html_control->load_data(
      IMPORTING
        assigned_url           = url    " URL
      CHANGING
        data_table             = html_table    " data table
      EXCEPTIONS
        dp_invalid_parameter   = 1
        dp_error_general       = 2
        cntl_error             = 3
        html_syntax_notcorrect = 4
        OTHERS                 = 5
    ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    html_control->show_url( url ).

  ENDMETHOD.


  METHOD get_pois_string.

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

        DATA(statement) = |SELECT "id", "geom".ST_X(), "geom".ST_Y() FROM qgis."gis_osm_places" where "name" = '{ zhdb_oms_screen_s-place }';|.

        DATA(result) = sql->execute_query( statement ).
        result->set_param_table( REF #( places ) ).
        result->next_package( ).

        DATA(geojson) = NEW zcl_geojson( ).

        DATA(place) = REF #( places[ 1 ] ).

        DATA(point) = geojson->get_new_point(
          i_latitude = place->latitude
          i_longitude = place->longitude
        ).
        point->set_properties( i_popup_content = CONV #( zhdb_oms_screen_s-place )
                               i_fill_color    = '#ff8888'
                               i_color         = '#ff0000' ).

        geojson->add_feature( point ).

        statement = |SELECT pois."id", pois."geom".ST_X(), pois."geom".ST_Y()| &&
                    |   FROM qgis."gis_osm_places" place| &&
                    |   INNER JOIN QGIS."gis_osm_pois" pois| &&
                    |   on pois."fclass" = '{ zhdb_oms_screen_s-poi_type }'| &&
                    |   and pois."geom".ST_Distance(place."geom") < { zhdb_oms_screen_s-range }| &&
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
              i_popup_content = CONV #( zhdb_oms_screen_s-poi_type ) ).
          geojson->add_feature( point ).
        ENDLOOP.

        r_result = NEW zcl_geojson_leafletjs( )->get_html(
          i_json = geojson->get_json( )
          i_use_circle_markers = abap_true ).

      CATCH cx_sy_itab_line_not_found.
        MESSAGE 'Place not found' TYPE 'I' ##no_text.

      CATCH cx_sql_exception INTO DATA(lcx).
        MESSAGE lcx TYPE 'I'.

      CATCH cx_parameter_invalid INTO DATA(lcx_parameter).    "
        MESSAGE lcx_parameter TYPE 'I'.

    ENDTRY.


  ENDMETHOD.

  METHOD string_to_table.

    DATA: split_table TYPE TABLE OF string,
          line        TYPE char1024.

    SPLIT i_html_string AT space INTO TABLE split_table.

    LOOP AT split_table REFERENCE INTO DATA(split).
      DATA(len) = strlen( line ) + strlen( split->* ).
      IF len LT 1024.
        CONCATENATE line split->* INTO line SEPARATED BY space.
      ELSE.
        INSERT line INTO TABLE r_result.
        line = split->*.
      ENDIF.
    ENDLOOP.
    INSERT line INTO TABLE r_result.

  ENDMETHOD.

ENDCLASS.
*&---------------------------------------------------------------------*
*& Module STATUS_9000 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9000 OUTPUT.
  g_app->status_9000( ).
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9000  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_9000 INPUT.
  g_app->user_command_9000( ).
ENDMODULE.
