--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.5
-- Dumped by pg_dump version 9.3.5
-- Started on 2014-10-31 21:59:59 CET

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 171 (class 3079 OID 11799)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 1987 (class 0 OID 0)
-- Dependencies: 171
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 170 (class 1259 OID 16386)
-- Name: reports; Type: TABLE; Schema: public; Owner: cpandatesters; Tablespace: 
--

CREATE TABLE reports (
    id serial,
    distname character varying(64),
    distauth character varying(64),
    distver character varying(32),
    compver character varying(32),
    backend character varying(16),
    osname character varying(32),
    osver character varying(32),
    arch character varying(64),
    raw json
);


ALTER TABLE public.reports OWNER TO cpandatesters;

--
-- TOC entry 1979 (class 0 OID 16386)
-- Dependencies: 170
-- Data for Name: reports; Type: TABLE DATA; Schema: public; Owner: cpandatesters
--

COPY reports (id, distname, distauth, distver, compver, backend, osname, osver, arch, raw) FROM stdin;
\.


--
-- TOC entry 1871 (class 2606 OID 16390)
-- Name: id; Type: CONSTRAINT; Schema: public; Owner: cpandatesters; Tablespace: 
--

ALTER TABLE ONLY reports
    ADD CONSTRAINT id PRIMARY KEY (id);


--
-- TOC entry 1986 (class 0 OID 0)
-- Dependencies: 5
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2014-10-31 21:59:59 CET

--
-- PostgreSQL database dump complete
--

